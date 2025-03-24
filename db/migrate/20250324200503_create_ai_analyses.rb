class CreateAiAnalyses < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_analyses do |t|
      t.references :metric, null: false, foreign_key: true
      t.integer :analysis_type
      t.json :parameters
      t.json :results

      t.timestamps
    end
  end
end
