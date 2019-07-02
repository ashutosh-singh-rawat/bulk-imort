class ReportsController < ApplicationController
  before_action :set_employee, only: [:show, :edit, :update, :destroy]

  # GET /employees
  def index
    params[:company_id] ||= Company.first.try(:id)
    @employees = Employee.includes(:company, :policies).where('companies.id = ?', params[:company_id]).references(:companies)
  end

  # POST /employees/import
  def import
    @result = ImportTaskResult.create
    path = Rails.root.join("tmp", "#{Time.now.to_i}#{params[:file].original_filename}")
    File.open(path, 'w') { |f| f.write(File.read(params[:file].path)) }
    Delayed::Job.enqueue(ImportDataJob.new(@result.id, path, params[:company_id]))
    respond_to do |format|
      format.js { render layout: false }
    end
  end

  def import_status
    result = ImportTaskResult.find_by(token: params[:token])
    render json: {token: result.token, status: result.status, progress: "#{result.progress_percent}%", url: result.file_url}
  end


end
