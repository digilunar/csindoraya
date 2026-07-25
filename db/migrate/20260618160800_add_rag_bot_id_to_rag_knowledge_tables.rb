class AddRagBotIdToRagKnowledgeTables < ActiveRecord::Migration[7.0]
  def change
    add_reference :rag_documents, :rag_bot, null: true, foreign_key: true
    add_reference :rag_knowledge_entries, :rag_bot, null: true, foreign_key: true
  end
end
