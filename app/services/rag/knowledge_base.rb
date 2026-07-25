# frozen_string_literal: true

module Rag
  class KnowledgeBase
    def initialize(account_id: nil)
      @account_id = account_id
    end

    def search(query, limit: 5)
      results = []

      # Search account-specific knowledge
      results += search_account_knowledge(query, limit) if @account_id

      # Search global knowledge (always included)
      results += search_global_knowledge(query, limit)

      # Deduplicate by fingerprint
      deduplicate_results(results)
    end

    def add_knowledge(content:, scope: :account, metadata: {})
      case scope.to_sym
      when :account
        add_account_knowledge(content, metadata)
      when :global
        add_global_knowledge(content, metadata)
      else
        raise ArgumentError, "Invalid scope: #{scope}"
      end
    end

    def self.supported_scopes
      %i[account global]
    end

    private

    attr_reader :account_id

    def search_account_knowledge(query, limit)
      return [] unless @account_id

      # Try vector search first, fallback to keyword
      vector_search(query, @account_id, limit) || keyword_search(query, @account_id, limit)
    end

    def search_global_knowledge(query, limit)
      vector_search(query, nil, limit) || keyword_search(query, nil, limit)
    end

    def vector_search(query, account_id, limit)
      return nil unless vector_search_available?

      embeddings = Rag::EmbeddingService.new(account_id: account_id).get_embedding(query)
      Rag::KnowledgeEntry.nearest_neighbors(:embedding, embeddings, distance: :cosine)
                         .limit(limit)
                         .to_a
    rescue StandardError
      nil
    end

    def keyword_search(query, account_id, limit)
      scope = account_id ? Rag::KnowledgeEntry.where(account_id: account_id) : Rag::KnowledgeEntry.global

      scope.where('LOWER(question) LIKE ? OR LOWER(answer) LIKE ?',
                  "%#{query.downcase}%",
                  "%#{query.downcase}%")
           .limit(limit)
           .to_a
    end

    def vector_search_available?
      return false unless ChatwootApp.enterprise?
      return false unless defined?(Rag::KnowledgeEntry)

      Rag::KnowledgeEntry.column_names.include?('embedding')
    rescue StandardError
      false
    end

    def add_account_knowledge(content, metadata)
      raise ArgumentError, 'Account ID required' unless @account_id

      Rag::KnowledgeEntry.create!(
        account_id: @account_id,
        question: extract_question(content),
        answer: content,
        scope: 'account',
        metadata: metadata
      )
    end

    def add_global_knowledge(content, metadata)
      Rag::KnowledgeEntry.create!(
        account_id: nil,
        question: extract_question(content),
        answer: content,
        scope: 'global',
        metadata: metadata
      )
    end

    def extract_question(content)
      content.to_s.split("\n").first&.truncate(200) || 'Knowledge Entry'
    end

    def deduplicate_results(results)
      seen = Set.new
      results.reject do |r|
        fingerprint = "#{r.question}|#{r.answer}"
        !seen.add?(fingerprint)
      end
    end
  end
end