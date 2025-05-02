class AddFieldsToAiAnalyses < ActiveRecord::Migration[7.2]
  def up
    # Проверяем наличие колонок перед добавлением
    add_column :ai_analyses, :status, :string unless column_exists?(:ai_analyses, :status)
    add_column :ai_analyses, :report, :json unless column_exists?(:ai_analyses, :report)
    add_column :ai_analyses, :completed_at, :datetime unless column_exists?(:ai_analyses, :completed_at)
  end
  
  def down
    remove_column :ai_analyses, :status if column_exists?(:ai_analyses, :status)
    remove_column :ai_analyses, :report if column_exists?(:ai_analyses, :report)
    remove_column :ai_analyses, :completed_at if column_exists?(:ai_analyses, :completed_at)
  end
end
