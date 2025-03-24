class CreateAlerts < ActiveRecord::Migration[7.2]
  def change
    create_table :alerts do |t|
      t.string :service
      t.string :metric
      t.float :value
      t.float :threshold
      t.string :status
      t.string :severity
      t.text :message
      t.datetime :triggered_at
      t.datetime :resolved_at

      t.timestamps
    end
  end
end
