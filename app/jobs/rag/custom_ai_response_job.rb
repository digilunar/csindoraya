class Rag::CustomAiResponseJob < ApplicationJob
  queue_as :rag

  def perform(account_id, conversation_id, message_content)
    account = Account.find_by(id: account_id)
    conversation = Conversation.find_by(id: conversation_id)
    return unless account && conversation
    
    integration = account.custom_ai_integration
    return unless integration&.endpoint_url.present?

    # 1. Search knowledge base
    kb = Rag::KnowledgeBase.new(account_id: account.id)
    context = kb.search(message_content)

    # 2. Prepare payload
    system_prompt = integration.system_prompt.presence || "Anda adalah asisten AI yang membantu."
    
    payload = {
      model: integration.model_name.presence || "default-model",
      messages: [
        { role: 'system', content: build_system_prompt(system_prompt, context) },
        { role: 'user', content: message_content }
      ]
    }

    # 3. Call Custom AI Endpoint
    response = call_custom_endpoint(integration, payload)
    
    if response.present?
      # 4. Reply to conversation using Chatwoot internal service
      bot_message = conversation.messages.create!(
        account_id: account.id,
        inbox_id: conversation.inbox_id,
        message_type: :outgoing,
        content: response
      )
    end
  rescue => e
    Rails.logger.error("CustomAiResponseJob Failed: #{e.message}")
  end

  private

  def build_system_prompt(base_prompt, context)
    return base_prompt if context.blank?
    
    context_str = context.map do |c|
      c.respond_to?(:answer) ? c.answer.to_s : (c[:content] || c['content'] || c.to_s)
    end.join("\n\n")
    
    <<~PROMPT
      #{base_prompt}

      KONTEKS (dari database pengetahuan):
      #{context_str}

      INSTRUKSI:
      - Jawab pertanyaan user berdasarkan konteks di atas jika memungkinkan.
      - Jangan mengarang informasi di luar konteks yang diberikan.
    PROMPT
  end

  def call_custom_endpoint(integration, payload)
    headers = { 'Content-Type' => 'application/json' }
    headers['Authorization'] = "Bearer #{integration.api_key}" if integration.api_key.present?

    conn = Faraday.new(url: integration.endpoint_url) do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
    end

    response = conn.post do |req|
      req.headers = headers
      req.body = payload
    end

    if response.success?
      # Try to parse OpenAI format response
      if response.body.is_a?(Hash) && response.body.dig('choices', 0, 'message', 'content')
        response.body.dig('choices', 0, 'message', 'content')
      elsif response.body.is_a?(Hash) && response.body['response']
        # Try to parse Ollama format
        response.body['response']
      else
        response.body.to_s
      end
    else
      Rails.logger.error("Custom AI Endpoint Error: #{response.status} - #{response.body}")
      nil
    end
  end
end
