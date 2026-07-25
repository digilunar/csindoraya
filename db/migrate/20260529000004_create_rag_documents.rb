# frozen_string_literal: true

class CreateRagDocuments < ActiveRecord::Migration[7.0]
  def change
    create_table :rag_documents do |t|
      t.integer :account_id
      t.integer :uploaded_by_id
      t.string :name, null: false
      t.string :file_type, null: false
      t.integer :status, default: 0, null: false
      t.integer :scope, default: 0, null: false
      t.string :last_error
      t.datetime :processed_at

      t.timestamps
    end

    add_index :rag_documents, :account_id
    add_index :rag_documents, :scope
    add_index :rag_documents, :status
  end
end