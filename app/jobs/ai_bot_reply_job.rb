class AiBotReplyJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message
    return unless message.incoming? # Only reply to incoming messages

    conversation = message.conversation
    account = conversation.account
    
    # Check if AI is enabled
    custom_attributes = account.custom_attributes || {}
    return unless custom_attributes['ai_enabled'] == 'true' || custom_attributes['ai_enabled'] == true

    # Only reply if the conversation is unassigned or assigned to a bot (prevent interfering with human agents)
    # Chatwoot's conversation status 0 is 'open', and assignee_id is the human agent
    return if conversation.assignee_id.present?

    ai_endpoint = custom_attributes['ai_endpoint']
    ai_api_key = custom_attributes['ai_api_key']
    ai_model = custom_attributes['ai_model'] || 'gpt-3.5-turbo'
    system_prompt = custom_attributes['rag_system_prompt'] || 'You are a helpful assistant.'
    
    # Retrieve RAG Context
    rag_context = ""
    begin
      knowledge_base = Rag::KnowledgeBase.new(account_id: account.id)
      search_results = knowledge_base.search(message.content, limit: 3)
      if search_results.present?
        context_text = search_results.map(&:answer).join("\n\n---\n\n")
        rag_context = "\n\nGunakan informasi berikut sebagai konteks untuk menjawab (jika relevan):\n#{context_text}"
      end
    rescue StandardError => e
      Rails.logger.error "RAG Knowledge Base error: #{e.message}"
    end

    return if ai_endpoint.blank?

    # Prepare chat history
    messages_payload = [{ role: 'system', content: system_prompt + rag_context }]
    
    # Get last 10 messages for context
    recent_messages = conversation.messages.where(message_type: [:incoming, :outgoing]).order(created_at: :desc).limit(10).reverse
    
    recent_messages.each do |msg|
      next if msg.content.blank?
      role = msg.incoming? ? 'user' : 'assistant'
      messages_payload << { role: role, content: msg.content }
    end

    ai_endpoint = ai_endpoint.chomp('/')
    ai_endpoint += '/chat/completions' unless ai_endpoint.end_with?('/chat/completions')

    # Send request to AI Endpoint
    begin
      uri = URI.parse(ai_endpoint)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')

      request = Net::HTTP::Post.new(uri.request_uri, {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ai_api_key}"
      })
      
      request.body = {
        model: ai_model,
        messages: messages_payload,
        stream: false
      }.to_json

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        result = JSON.parse(response.body)
        reply_content = result.dig('choices', 0, 'message', 'content')
        
        if reply_content.present?
          # Create a reply in the conversation
          Messages::MessageBuilder.new(
            nil, # user
            conversation,
            {
              content: reply_content,
              message_type: :outgoing
            }
          ).perform
        end
      else
        Rails.logger.error "AI Bot Error: #{response.code} - #{response.body}"
      end
    rescue StandardError => e
      Rails.logger.error "AI Bot Exception: #{e.message}"
    end
  end
end
