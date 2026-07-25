# frozen_string_literal: true

class CreateTelegramRagDocuments < ActiveRecord::Migration[7.0]
  def change
    create_table :telegram_rag_documents do |t|
      t.integer :account_id, null: false
      t.string :name, null: false
      t.string :file_type, null: false
      t.text :content
      t.jsonb :metadata, default: {}
      t.integer :status, default: 0, null: false
      t.string :last_error
      t.datetime :processed_at

      t.timestamps
    end

    add_index :telegram_rag_documents, :account_id
    add_index :telegram_rag_documents, :status
  end
end