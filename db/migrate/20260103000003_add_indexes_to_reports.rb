class AddIndexesToReports < ActiveRecord::Migration[7.2]
  def change
    add_index :reports, [ :report_type, :status ], name: "index_reports_on_report_type_and_status"
    add_index :reports, [ :expires_at, :status ],  name: "index_reports_on_expires_at_and_status"
  end
end
