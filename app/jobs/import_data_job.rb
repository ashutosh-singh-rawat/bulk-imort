require 'csv'
class ImportDataJob < Struct.new(:task_id, :file_path, :company_id)
  @@report_to = {}
  @@policies = {}

  def perform
    tsk = ImportTaskResult.find(task_id)
    tsk.update_attributes(status: 'started', progress_percent: 20.0)
    emps_with_reportee_not_found = []
    failed_instances  = []

    import_data(emps_with_reportee_not_found, failed_instances, tsk)
    tsk.update_attributes(status: 'started', progress_percent: 40.0)
    retry_with_new_reportees(emps_with_reportee_not_found, failed_instances, tsk)

    csv_rows = []
    generate_csv_for(csv_rows, failed_instances, emps_with_reportee_not_found.map{|e| e[0]})
    wrtie_errors_csv(csv_rows.join(""), tsk)
    clean_job
  end

  def clean_job
    File.delete(file_path) if File.exists?(file_path)
    @@report_to = {}
    @@policies = {}
    sleep 20
    File.delete(@result_path) if File.exists?(@result_path)
  end

  def wrtie_errors_csv(csv_content, tsk)
    result_file = "ImportResult-#{Time.zone.today}-#{tsk.token}.csv"
    @result_path = Rails.root.join("public", "import_results", result_file)
    File.open(@result_path, 'w') { |f| f.write(csv_content) }
    tsk.update_attributes(status: 'finished', progress_percent: 100, file_url: "/import_results/#{result_file}")
  end

  def import_data(emps_with_reportee_not_found, failed_instances, tsk)
    converter = lambda { |header| header.parameterize }
    valid_emps = []
    CSV.foreach(file_path, headers: true, header_converters: converter) do |row|
      emp = Employee.new(name: row['employee-name'], email: row['email'], company_id: company_id, phone: row['phone'])
      if row['report-to'].present?
        reportee = reportee(row['report-to'])
        if reportee
          emp.parent = reportee
        else
          emps_with_reportee_not_found << [emp, row['report-to'], row['assigned-policies']]
          emp = nil
        end
      end
      if emp && row['assigned-policies'].present?
        pols = get_policies(row['assigned-policies'])
        pols.each{|policy| emp.employees_policies.build(policy: policy)  }
      end
      valid_emps << emp if emp
    end

    response = Employee.import(valid_emps, recursive: true, batch_size: 1000, validate: true, validate_uniqueness: true)
    failed_instances.push *response.failed_instances
  end

  def reportee(email)
    unless @@report_to[email]
      e = Employee.find_by(email: email, company_id: company_id)
      @@report_to[email] = e if e
    end
    @@report_to[email]
  end

  def get_policies(names)
    p = []
    names.split("|").each do |name|
      name.squish!
      unless @@policies[name]
        e = Policy.find_or_create_by(name: name, company_id: company_id)
        @@policies[name] = e if e
      end
      p << @@policies[name]
    end
    p
  end

  def generate_csv_for(yielder, failed_instances, invalid_emps)
    # first line is column names
    yielder << [
      'Employee Name',
      'Email',
      'Remarks'
    ].to_csv(force_quotes: true)

    failed_instances.each do |ins|
      yielder << [
        ins.name,
        ins.email,
        ins.errors.full_messages.join(', ')
      ].to_csv(force_quotes: true)
    end
    invalid_emps.each do |ins|
      yielder << [
        ins.name,
        ins.email,
        "No reportee exists at the time of uploading. Try importing Again."
      ].to_csv(force_quotes: true)
    end
    yielder
  end

  def retry_with_new_reportees(emps_with_reportee_not_found, failed_instances, tsk)
    count = 0
    tsk.update_attributes(status: 'started', progress_percent: 70.0)
    while emps_with_reportee_not_found.count > 0 && emps_with_reportee_not_found.count != count
      count = emps_with_reportee_not_found.count
      emps_with_reportee = []
      emps_non_repotee = []
      emps_with_reportee_not_found.each do |d|
        emply, reportee_email, policy_name = d
        rpte = reportee(reportee_email)
        if rpte
          emply.parent = rpte
          if policy_name.present?
            pols = get_policies(policy_name)
            pols.each{|policy| emply.employees_policies.build(policy: policy)  }
          end
          emps_with_reportee << emply
        else
          emps_non_repotee << [emply, reportee_email, policy_name]
        end
        res = Employee.import(emps_with_reportee, recursive: true, batch_size: 1000, validate: true, validate_uniqueness: true)
        emps_with_reportee = []
        failed_instances.push *res.failed_instances
      end
      emps_with_reportee_not_found.clear
      emps_with_reportee_not_found.push  *emps_non_repotee
    end
    tsk.update_attributes(status: 'started', progress_percent: 90.0)
  end
end
