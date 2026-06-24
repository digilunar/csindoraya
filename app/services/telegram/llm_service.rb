# frozen_string_literal: true

module Telegram
  class LlmService
    include Integrations::LlmInstrumentation

    class LlmError < StandardError; end

    PROVIDERS = {
      openai: 'openai',
      anthropic: 'anthropic',
      azure: 'azure'
    }.freeze

    def initialize(provider: nil, model: nil, account_id: nil)
      @provider = provider || default_provider
      @model = model || default_model
      @account = Account.find_by(id: account_id) if account_id
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
    rescue StandardError => e
      Rails.logger.error "LLM generation failed: #{e.message}"
      raise LlmError, e.message
    end

    def self.rag_prompt_template
      <<~PROMPT
        Anda adalah asisten customer support yang membantu.

        KONTEKS (dari database pengetahuan):
        %{context}

        PERTANYAAN USER:
        %{question}

        INSTRUKSI:
        - Jawab berdasarkan konteks di atas
        - Jika konteks tidak relevan, katakan "Maaf, saya tidak menemukan informasi terkait pertanyaan Anda"
        - Gunakan bahasa yang sopan dan natural
        - Jangan mengarang informasi

        JAWABAN:
      PROMPT
    end

    private

    attr_reader :provider, :model

    def build_prompt(question, context)
      if context.present?
        context_str = context.is_a?(Array) ? context.map { |c| c[:content] || c['content'] || c.to_s }.join("\n\n") : context.to_s
        system_prompt = @account&.custom_attributes&.dig('rag_system_prompt').presence || "Anda adalah asisten customer support yang membantu."
        
        prompt_template = <<~PROMPT
          #{system_prompt}

          KONTEKS (dari database pengetahuan):
          %{context}

          PERTANYAAN USER:
          %{question}

          INSTRUKSI:
          - Jawab berdasarkan konteks di atas
          - Jika konteks tidak relevan, katakan "Maaf, saya tidak menemukan informasi terkait pertanyaan Anda"
          - Gunakan bahasa yang sopan dan natural
          - Jangan mengarang informasi

          JAWABAN:
        PROMPT
        
        prompt_template % { context: context_str, question: question }
      else
        question
      end
    end

    def call_anthropic(prompt, temperature)
      require 'anthropic'

      client = Anthropic::Client.new(access_token: anthropic_api_key)
      response = client.messages(parameters: {
        model: model || 'claude-sonnet-4-6-20250929',
        max_tokens: 1024,
        temperature: temperature,
        messages: [{ role: 'user', content: prompt }]
      })

      response['content'].first['text']
    end

    def call_openai(prompt, temperature)
      require 'openai'

      client = OpenAI::Client.new(access_token: openai_api_key)
      response = client.chat(parameters: {
        model: model || 'gpt-4o-mini',
        messages: [{ role: 'user', content: prompt }],
        temperature: temperature
      })

      response['choices'].first['message']['content']
    end

    def call_azure(prompt, temperature)
      require 'openai'

      client = OpenAI::Client.new(
        access_token: azure_api_key,
        uri_base: azure_endpoint
      )

      response = client.chat(parameters: {
        model: model || azure_deployment_name,
        messages: [{ role: 'user', content: prompt }],
        temperature: temperature
      })

      response['choices'].first['message']['content']
    rescue StandardError => e
      Rails.logger.error "Azure OpenAI call failed: #{e.message}"
      raise
    end

    def default_provider
      ENV.fetch('TELEGRAM_RAG_LLM_PROVIDER', 'anthropic').to_sym
    end

    def default_model
      case @provider
      when :anthropic
        'claude-sonnet-4-6-20250929'
      when :openai
        'gpt-4o-mini'
      when :azure
        nil
      end
    end

    def anthropic_api_key
      ENV.fetch('ANTHROPIC_API_KEY', nil)
    end

    def openai_api_key
      ENV.fetch('OPENAI_API_KEY', nil)
    end

    def azure_api_key
      ENV.fetch('AZURE_OPENAI_API_KEY', nil)
    end

    def azure_endpoint
      ENV.fetch('AZURE_OPENAI_ENDPOINT', nil)
    end

    def azure_deployment_name
      ENV.fetch('AZURE_OPENAI_DEPLOYMENT', nil)
    end
  end
end