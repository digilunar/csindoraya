# frozen_string_literal: true

class Rag::ResponseJob < ApplicationJob
  queue_as :rag

  def perform(channel_type, inbound_message_id, message_content)
    inbound_message = Message.find_by(id: inbound_message_id)
    return unless inbound_message

    account = inbound_message.account
    return unless account

    knowledge_base = Rag::KnowledgeBase.new(account_id: account.id)
    llm_service = Rag::LlmService.new(account: account)

    search_results = knowledge_base.search(message_content, limit: 5)

    if search_results.blank?
      send_fallback_response(inbound_message, account)
    else
      generate_and_send_response(inbound_message, llm_service, message_content, search_results, channel_type)
    end
  rescue StandardError => e
    Rails.logger.error "Rag::ResponseJob failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  private

  def send_fallback_response(inbound_message, account)
    fallback_text = ENV.fetch('RAG_FALLBACK_MESSAGE', 'Maaf, saya tidak menemukan informasi terkait pertanyaan Anda.')
    create_outgoing_message(inbound_message, fallback_text)
  end

  def generate_and_send_response(inbound_message, llm_service, question, context, channel_type)
    prompt = "#{question}\n\nTolong jawab berdasarkan informasi yang tersedia."
    response_text = llm_service.generate(prompt: prompt, context: context)

    case channel_type.to_s
    when 'telegram'
      create_outgoing_message(inbound_message, response_text)
    when 'whatsapp'
      create_outgoing_message(inbound_message, response_text)
    else
      create_outgoing_message(inbound_message, response_text)
    end
  end

  def create_outgoing_message(inbound_message, content)
    conversation = inbound_message.conversation
    return unless conversation

    conversation.messages.create!(
      account: conversation.account,
      inbox: conversation.inbox,
      sender: nil,
      content: content,
      message_type: :outgoing,
      content_type: 'text'
    )
  end
end