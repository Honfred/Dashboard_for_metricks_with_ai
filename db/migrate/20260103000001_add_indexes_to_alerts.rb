class AddIndexesToAlerts < ActiveRecord::Migration[7.2]
  def change
    add_index :alerts, [ :service, :metric, :status ], name: "index_alerts_on_service_metric_status"
    add_index :alerts, [ :status, :triggered_at ],     name: "index_alerts_on_status_and_triggered_at"
    add_index :alerts, [ :severity, :status ],         name: "index_alerts_on_severity_and_status"
  end
end
