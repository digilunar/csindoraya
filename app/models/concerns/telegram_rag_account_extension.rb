# frozen_string_literal: true

class Account < ApplicationRecord
  # Add association for Telegram RAG documents
  has_many :telegram_rag_documents, dependent: :destroy, class_name: 'Telegram::RagDocument'

  def telegram_rag_enabled?
    feature_enabled?('telegram_rag')
  end
end