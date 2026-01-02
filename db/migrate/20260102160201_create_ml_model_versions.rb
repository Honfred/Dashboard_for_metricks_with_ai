# frozen_string_literal: true

class CreateMlModelVersions < ActiveRecord::Migration[7.2]
  def change
    create_table :ml_model_versions do |t|
      t.string :model_type, null: false  # anomaly, performance, trend
      t.string :version, null: false
      t.string :status, null: false, default: 'training'
      t.jsonb :metadata, default: {}
      t.jsonb :metrics, default: {}      # accuracy, f1_score, etc.
      t.datetime :trained_at
      t.datetime :deployed_at
      t.boolean :is_active, default: false

      t.timestamps
    end

    add_index :ml_model_versions, :model_type
    add_index :ml_model_versions, :status
    add_index :ml_model_versions, [:model_type, :is_active]
    add_index :ml_model_versions, :version
  end
end
