class AddFieldsToMetrics < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:metrics, :display_name)
      add_column :metrics, :display_name, :string
    end

    unless column_exists?(:metrics, :unit)
      add_column :metrics, :unit, :string
    end
  end
end
