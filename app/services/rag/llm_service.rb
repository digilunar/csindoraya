# frozen_string_literal: true

module Rag
  class LlmService
    class LlmError < StandardError; end

    def initialize(provider: nil, model: nil, account: nil)
      @provider = provider || default_provider
      @model = model || default_model
      @account = account
    end

    def generate(prompt:, context: nil, temperature: 0.7)
      full_prompt = build_prompt(prompt, context)

      case @provider
      when :anthropic
        call_anthropic(full_prompt, temperature)
      when :openai
        call_openai(full_prompt, temperature)
      when :azure
        call_azure(full_prompt, temperature)
      else
        raise LlmError, "Unknown provider: #{@provider}"
      end
    end

    private

    def build_prompt(question, context)
      system_prompt = @account&.custom_attributes&.dig('rag_system_prompt').presence || "Anda adalah asisten customer support yang membantu."
      
      if context.present?
        context_str = format_context(context)
        <<~PROMPT
          #{system_prompt}

          KONTEKS (dari database pengetahuan):
          #{context_str}

          PERTANYAAN USER:
          #{question}

          INSTRUKSI:
          - Jawab berdasarkan konteks di atas
          - Jika konteks tidak relevan, katakan "Maaf, saya tidak menemukan informasi terkait pertanyaan Anda"
          - Gunakan bahasa yang sopan dan natural
          - Jangan mengarang informasi

          JAWABAN:
        PROMPT
      else
        question
      end
    end

    def format_context(context)
      case context
      when Array
        context.map do |c|
          if c.respond_to?(:answer)
            # KnowledgeEntry ActiveRecord object
            c.answer.to_s
          else
            c[:content] || c['content'] || c.to_s
          end
        end.join("\n\n")
      when Hash
        context[:content] || context['content'] || context.to_s
      else
        context.to_s
      end
    end

    def call_anthropic(prompt, temperature)
      require 'anthropic'

      client = Anthropic::Client.new(access_token: anthropic_api_key)
      response = client.messages(parameters: {
        model: @model || 'claude-sonnet-4-6-20250929',
        max_tokens: 1024,
        temperature: temperature,
        messages: [{ role: 'user', content: prompt }]
      })

      response['content'].first['text']
    end

    def call_openai(prompt, temperature)
      api_key = ENV.fetch('OPENAI_API_KEY')
      api_base = ENV.fetch('OPENAI_API_BASE', 'https://api.openai.com/v1').chomp('/')
      model_name = @model || ENV.fetch('RAG_LLM_MODEL', 'gpt-4o-mini')

      conn = Faraday.new do |f|
        f.request :json
        f.response :json
        f.adapter Faraday.default_adapter
      end

      response = conn.post("#{api_base}/chat/completions") do |req|
        req.headers['Authorization'] = "Bearer #{api_key}"
        req.headers['Content-Type'] = 'application/json'
        req.body = {
          model: model_name,
          messages: [{ role: 'user', content: prompt }],
          temperature: temperature
        }
      end

      if response.success?
        response.body.dig('choices', 0, 'message', 'content') || ''
      else
        error = response.body.is_a?(Hash) ? response.body.dig('error', 'message') : response.body.to_s
        raise LlmError, "LLM API error #{response.status}: #{error}"
      end
    end

    def call_azure(prompt, temperature)
      require 'openai'

      client = OpenAI::Client.new(
        access_token: azure_api_key,
        uri_base: azure_endpoint
      )

      response = client.chat(parameters: {
        model: @model || azure_deployment_name,
        messages: [{ role: 'user', content: prompt }],
        temperature: temperature
      })

      response['choices'].first['message']['content']
    end

    def default_provider
      ENV.fetch('RAG_LLM_PROVIDER', 'openai').to_sym
    end

    def default_model
      case @provider
      when :anthropic then 'claude-sonnet-4-6-20250929'
      when :openai then 'gpt-4o-mini'
      end
    end

    def anthropic_api_key
      ENV.fetch('ANTHROPIC_API_KEY')
    end

    def openai_api_key
      ENV.fetch('OPENAI_API_KEY')
    end

    def azure_api_key
      ENV.fetch('AZURE_OPENAI_API_KEY')
    end

    def azure_endpoint
      ENV.fetch('AZURE_OPENAI_ENDPOINT')
    end

    def azure_deployment_name
      ENV.fetch('AZURE_OPENAI_DEPLOYMENT')
    end
  end
end