# frozen_string_literal: true

class CreateRagKnowledgeEntries < ActiveRecord::Migration[7.0]
  def change
    create_table :rag_knowledge_entries do |t|
      t.integer :account_id
      t.integer :uploaded_by
      t.string :question, null: false
      t.text :answer, null: false
      t.integer :scope, default: 0, null: false
      t.vector :embedding, limit: 1536
      t.jsonb :metadata, default: {}
      t.boolean :edited, default: false

      t.timestamps
    end

    add_index :rag_knowledge_entries, :account_id
    add_index :rag_knowledge_entries, :scope
    add_index :rag_knowledge_entries, :updated_at
    add_index :rag_knowledge_entries, :embedding, using: :ivfflat if ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
  end
end