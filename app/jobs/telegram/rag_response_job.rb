# frozen_string_literal: true

class Telegram::RagResponseJob < ApplicationJob
  queue_as :telegram_rag

  def perform(account_id, inbound_message_id, message_content)
    inbound_message = Message.find_by(id: inbound_message_id)
    return unless inbound_message

    account = Account.find_by(id: account_id)
    return unless account

    rag_service = Telegram::RagService.new(account_id: account_id)
    llm_service = Telegram::LlmService.new(account_id: account_id)

    search_results = rag_service.search(message_content, limit: 5)

    if search_results.blank?
      send_fallback_response(inbound_message, account)
    else
      generate_and_send_response(inbound_message, llm_service, message_content, search_results)
    end
  rescue StandardError => e
    Rails.logger.error "Telegram::RagResponseJob failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  private

  def send_fallback_response(inbound_message, account)
    fallback_text = ENV.fetch('TELEGRAM_RAG_FALLBACK_MESSAGE', 'Maaf, saya belum mengerti pertanyaan Anda. Apakah ada yang bisa saya bantu?')

    create_outgoing_message(inbound_message, fallback_text)
  end

  def generate_and_send_response(inbound_message, llm_service, question, context)
    prompt = "#{question}\n\nTolong jawab berdasarkan informasi yang tersedia."

    response_text = llm_service.generate(prompt: prompt, context: context)

    create_outgoing_message(inbound_message, response_text)
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