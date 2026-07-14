class AddIndexesToAiAnalyses < ActiveRecord::Migration[7.2]
  def change
    add_index :ai_analyses, [ :analysis_type, :status, :created_at ], name: "index_ai_analyses_on_type_status_created_at"
    add_index :ai_analyses, [ :status, :created_at ],                 name: "index_ai_analyses_on_status_and_created_at"
  end
end
