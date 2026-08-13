# frozen_string_literal: true

class Rag::ResponseJob < ApplicationJob
  queue_as :rag

  def perform(channel_type, inbound_message_id, message_content)
    sleep(4) # Debounce 4 detik untuk menggabungkan pesan beruntun
    inbound_message = Message.find_by(id: inbound_message_id)
    return unless inbound_message

    conversation = inbound_message.conversation
    return unless conversation

    # 1. Deduplication & Debounce: Skip if there's a newer incoming message
    last_incoming = conversation.messages.incoming.order(created_at: :desc).first
    if last_incoming && last_incoming.id != inbound_message.id
      Rails.logger.info("Rag::ResponseJob skipped for message #{inbound_message.id}: a newer message exists in conversation #{conversation.id}")
      return
    end

    account = inbound_message.account
    return unless account

    # 2. Session Context: Merge recent unreplied messages
    last_outgoing = conversation.messages.outgoing.last
    recent_incoming_messages = if last_outgoing
                                 conversation.messages.incoming.where('created_at > ?', last_outgoing.created_at).order(:created_at)
                               else
                                 conversation.messages.incoming.order(:created_at)
                               end
    
    combined_content = recent_incoming_messages.pluck(:content).compact.join(" \n ")
    combined_content = message_content if combined_content.blank?

    # 3. Greeting Control: Check if we've greeted
    has_sent_greeting = conversation.messages.outgoing.where("content ILIKE ?", "%Salam Budaya%").exists?

    knowledge_base = Rag::KnowledgeBase.new(account_id: account.id)
    llm_service = Rag::LlmService.new(account: account)

    search_results = knowledge_base.search(combined_content, limit: 5)

    if search_results.blank?
      send_fallback_response(inbound_message, account)
    else
      generate_and_send_response(inbound_message, llm_service, combined_content, search_results, channel_type, has_sent_greeting)
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

  def generate_and_send_response(inbound_message, llm_service, question, context, channel_type, has_sent_greeting)
    prompt_prefix = if has_sent_greeting
                      "Jawab pertanyaan pengguna berikut dengan informatif."
                    else
                      "INSTRUKSI KHUSUS: Ini adalah pesan pertama dari pengguna. AWALI jawaban Anda persis dengan kalimat ini: 'Salam Budaya! Selamat datang di pusat layanan informasi kami.'\nJika pengguna hanya menyapa, jangan tambahkan kalimat lain selain menanyakan apa yang bisa dibantu."
                    end

    prompt = "#{prompt_prefix}\n\nPertanyaan:\n#{question}\n\nTolong jawab berdasarkan informasi yang tersedia."
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