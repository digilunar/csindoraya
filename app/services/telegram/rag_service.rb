# frozen_string_literal: true

module Telegram
  class RagService
    def initialize(account_id: nil)
      @account_id = account_id
      @account = Account.find_by(id: account_id) if account_id
    end

    def search(query, limit: 5)
      try_vector_search(query, limit) || keyword_search(query, limit)
    end

    def add_document(content:, source_type:, source_id: nil, metadata: {})
      response = Captain::AssistantResponse.new(
        question: extract_question_from_content(content),
        answer: content,
        account_id: @account_id,
        assistant_id: default_assistant_id,
        documentable: build_documentable(source_type, source_id, metadata)
      )
      response.save!
      response
    rescue StandardError => e
      Rails.logger.error "RAG add_document error: #{e.message}"
      nil
    end

    def vector_search_available?
      captain_available? && database_supports_vectors?
    end

    private

    attr_reader :account_id, :account

    def try_vector_search(query, limit)
      return nil unless vector_search_available?

      Captain::AssistantResponse.search(query, account_id: account_id).limit(limit).to_a
    rescue StandardError => e
      Rails.logger.warn "Vector search failed: #{e.message}, falling back to keyword search"
      nil
    end

    def keyword_search(query, limit)
      query_lower = "%#{query.downcase}%"
      Captain::AssistantResponse
        .where(account_id: account_id)
        .where('LOWER(question) LIKE ? OR LOWER(answer) LIKE ?', query_lower, query_lower)
        .limit(limit)
        .to_a
    end

    def captain_available?
      return false unless ChatwootApp.enterprise?
      return false unless defined?(Captain::AssistantResponse)
      return false unless @account_id

      default_assistant_id.present?
    rescue StandardError
      false
    end

    def database_supports_vectors?
      Captain::AssistantResponse.column_names.include?('embedding')
    rescue StandardError
      false
    end

    def default_assistant_id
      @default_assistant_id ||= Captain::Assistant.find_by(account_id: account_id)&.id
    rescue StandardError
      nil
    end

    def build_documentable(source_type, source_id, metadata)
      return nil unless source_type && source_id

      case source_type.to_s
      when 'telegram_message'
        Message.find_by(id: source_id)
      when 'document'
        Captain::Document.find_by(id: source_id)
      else
        nil
      end
    rescue StandardError
      nil
    end

    def extract_question_from_content(content)
      content.split("\n").first&.truncate(200) || 'FAQ Entry'
    end
  end
end