class CreateDashboardSettings < ActiveRecord::Migration[7.2]
  def change
    create_table :dashboard_settings do |t|
      t.string :name, null: false
      t.text :settings

      t.timestamps
    end
    
    add_index :dashboard_settings, :name, unique: true
  end
end
