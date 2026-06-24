# frozen_string_literal: true

module Rag
  class EmbeddingService
    include Integrations::LlmInstrumentation

    class EmbeddingsError < StandardError; end

    def initialize(account_id: nil)
      @account_id = account_id
      @model = ENV.fetch('RAG_EMBEDDING_MODEL', 'text-embedding-3-small')
      @api_key = ENV.fetch('OPENAI_API_KEY', '')
      @api_base = ENV.fetch('OPENAI_API_BASE', 'https://api.openai.com/v1').chomp('/')
    end

    def get_embedding(content, model: @model)
      return [] if content.blank?

      instrument_embedding_call(instrumentation_params(content, model)) do
        call_embedding_api(content, model)
      end
    rescue RubyLLM::Error => e
      Rails.logger.error "Embedding API Error: #{e.message}"
      raise EmbeddingsError, "Failed to create embedding: #{e.message}"
    rescue StandardError => e
      Rails.logger.error "Embedding Service Error: #{e.message}"
      raise EmbeddingsError, "Failed to create embedding: #{e.message}"
    end

    private

    attr_reader :account_id, :model, :api_key, :api_base

    def call_embedding_api(content, model, retries: 3)
      endpoint_url = "#{api_base}/embeddings"

      conn = Faraday.new do |f|
        f.request :json
        f.response :json
        f.adapter Faraday.default_adapter
      end

      response = conn.post(endpoint_url) do |req|
        req.headers['Authorization'] = "Bearer #{api_key}"
        req.headers['Content-Type'] = 'application/json'
        req.body = { input: content, model: model, dimensions: 1536 }
      end

      if response.success?
        data = response.body
        if data['data']&.first&.key?('embedding')
          data['data'].map { |d| d['embedding'] }.flatten
        else
          raise EmbeddingsError, "Unexpected embedding response: #{data.inspect[0..200]}"
        end
      elsif response.status == 429 && retries > 0
        wait_time = (4 - retries) * 5 # 5s, 10s, 15s
        Rails.logger.warn "Embedding API rate limited (429). Retrying in #{wait_time}s... (#{retries} retries left)"
        sleep(wait_time)
        call_embedding_api(content, model, retries: retries - 1)
      else
        error_msg = response.body.is_a?(Hash) ? response.body.dig('error', 'message') : response.body.to_s
        raise EmbeddingsError, "Embedding API returned #{response.status}: #{error_msg}"
      end
    end

    def instrumentation_params(content, model)
      {
        span_name: 'llm.rag.embedding',
        model: model,
        input: content,
        feature_name: 'rag_embedding',
        account_id: @account_id
      }
    end
  end
end