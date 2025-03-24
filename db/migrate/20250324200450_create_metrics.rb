class CreateMetrics < ActiveRecord::Migration[7.2]
  def change
    create_table :metrics do |t|
      t.string :name
      t.text :description
      t.integer :metric_type

      t.timestamps
    end
  end
end
