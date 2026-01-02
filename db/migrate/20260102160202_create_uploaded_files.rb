# frozen_string_literal: true

class CreateUploadedFiles < ActiveRecord::Migration[7.2]
  def change
    create_table :uploaded_files do |t|
      t.string :name, null: false
      t.string :file_type, null: false, default: 'other'
      t.string :category
      t.text :description
      t.jsonb :metadata, default: {}
      t.references :uploadable, polymorphic: true, index: true

      t.timestamps
    end

    add_index :uploaded_files, :file_type
    add_index :uploaded_files, :category
  end
end
