class AddIndexToMetricsName < ActiveRecord::Migration[7.2]
  def change
    add_index :metrics, :name, name: "index_metrics_on_name"
  end
end
