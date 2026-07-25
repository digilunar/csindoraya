# frozen_string_literal: true

module TelegramRagAccountExtension
  extend ActiveSupport::Concern

  included do
    has_many :telegram_rag_documents, dependent: :destroy, class_name: 'Telegram::RagDocument'
  end

  def telegram_rag_enabled?
    true
  end
end