# frozen_string_literal: true

class CreateReports < ActiveRecord::Migration[7.2]
  def change
    create_table :reports do |t|
      t.string :name, null: false
      t.string :report_type, null: false, default: 'metrics'
      t.string :format, null: false, default: 'pdf'
      t.string :status, null: false, default: 'pending'
      t.jsonb :parameters, default: {}
      t.jsonb :metadata, default: {}
      t.datetime :generated_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :reports, :report_type
    add_index :reports, :status
    add_index :reports, :created_at
  end
end
