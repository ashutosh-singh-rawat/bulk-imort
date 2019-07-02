class CreateImportTaskResults < ActiveRecord::Migration[5.2]
  def change
    create_table :import_task_results do |t|
      t.string :status
      t.string :token
      t.string :file_url
      t.float  :progress_percent, default: 0.0
      t.timestamps
    end
  end
end
