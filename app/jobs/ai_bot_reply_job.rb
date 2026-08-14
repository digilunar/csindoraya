class AiBotReplyJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message
    return unless message.incoming? # Only reply to incoming messages

    conversation = message.conversation
    return unless BotRoutingService.new(conversation: conversation).handles?(:custom_ai)

    # Prevent concurrent replies to burst messages: only reply if this is STILL the latest incoming message
    latest_incoming = conversation.messages.where(message_type: :incoming).reorder(created_at: :desc, id: :desc).first
    if latest_incoming && latest_incoming.id != message.id
      Rails.logger.info "Skipping AiBotReplyJob for older message #{message.id} because a newer message exists."
      return
    end

    deduplication = BotReplyDeduplicationService.new(
      conversation_id: conversation.id,
      incoming_message_id: message.id
    )
    return if deduplication.completed?
    return unless deduplication.with_lock do
      next if deduplication.completed?
      next unless conversation.messages.where(message_type: :incoming).reorder(created_at: :desc, id: :desc).pick(:id) == message.id

      perform_reply(message, conversation, account: conversation.account, deduplication: deduplication)
    end
  end

  private

  def perform_reply(message, conversation, account:, deduplication:)
    
    integration = account.custom_ai_integration
    return unless integration.present? && integration.endpoint_url.present?

    # Only reply if the conversation is unassigned or assigned to a bot (prevent interfering with human agents)
    return if conversation.assignee_id.present?
    # Stop replying if already handed over to a team
    # return if conversation.team_id.present? # Disabled: allow AI to reply until an agent is assigned

    ai_endpoint = integration.endpoint_url
    ai_api_key = integration.api_key
    ai_model = (integration.respond_to?(:ai_model) ? integration.ai_model : nil) || 'gpt-3.5-turbo'
    system_prompt = integration.system_prompt.presence || 'You are a helpful assistant.'
    
    # Retrieve RAG Context
    context_text = ""
    begin
      knowledge_base = Rag::KnowledgeBase.new(account_id: account.id)
      search_results = knowledge_base.search(message.content, limit: 3)
      if search_results.present?
        context_text = search_results.map(&:answer).join("\n\n---\n\n")
      end
    rescue StandardError => e
      Rails.logger.error "RAG Knowledge Base error: #{e.message}"
    end

    guardrails = ""
    if conversation.team_id.present?
      guardrails = <<~PROMPT

        INSTRUKSI PENTING / GUARDRAILS:
        - Percakapan ini SUDAH dialihkan ke tim layanan pelanggan (manusia).
        - Tugas Anda SEKARANG HANYA SATU: Beritahu pengguna dengan ramah bahwa pesan atau pertanyaan mereka telah diteruskan ke tim terkait, dan mohon kesediaannya untuk menunggu agen kami merespons.
        - JANGAN menjawab pertanyaan substansial tentang layanan atau memberikan informasi panjang.
        - Jika pengguna menanyakan perkembangan pertanyaannya, tegaskan kembali agar mereka bersabar menunggu balasan dari tim manusia kami.
      PROMPT
    else
      guardrails = <<~PROMPT

        KONTEKS (Informasi Resmi):
        #{context_text.present? ? context_text : "Tidak ada informasi spesifik di database."}

        INSTRUKSI PENTING / GUARDRAILS:
        1. Peran: Anda adalah Customer Service (CS) yang ramah untuk melayani pertanyaan seputar Dana Abadi Kebudayaan.
        2. Jika pengguna HANYA MENYAPA (misal: "halo", "malam", "pagi", "ping", dsb) atau pesan mereka sangat singkat:
           - BALASLAH SAPAAN TERSEBUT DENGAN SINGKAT DAN RAMAH.
           - Tanyakan apa yang bisa dibantu.
           - JANGAN memberikan penjelasan panjang tentang Dana Abadi jika belum ditanya.
        3. Jika pengguna bertanya tentang layanan dan informasinya ADA di KONTEKS:
           - Jawab HANYA berdasarkan informasi pada KONTEKS di atas secara detail dan ramah. Jangan mengarang.
        4. JIKA PENGGUNA BERTANYA SESUATU YANG TIDAK ADA DI KONTEKS, DI LUAR TOPIK, ATAU MEMINTA CS MANUSIA:
           - Jangan berbohong atau mengarang jawaban.
           - Tanyakan dan konfirmasi pertanyaannya, lalu berikan pesan menu pilihan tim CS persis seperti ini:
             "Mohon maaf kak, untuk informasi tersebut belum tersedia di sistem saya. Namun jangan khawatir, tim CS kami siap membantu Anda!

             Apakah Anda ingin saya teruskan ke tim terkait? Pilih angka untuk menghubungi tim yang sesuai: 

             1. Sekretariat
             Layanan informasi umum program, kendala website/aplikasi pendaftaran, kontrak/perjanjian pendanaan, serta informasi administratif lainnya.

             2. Verifikasi
             Layanan verifikasi dokumen, pendampingan penyusunan RAB, lokakarya, serta informasi mengenai progres pencairan pendanaan.

             3. Pemantauan dan Evaluasi
             Layanan informasi progres laporan kegiatan dan keuangan, hasil pemantauan dan evaluasi, serta tindak lanjut pendanaan.

             Mohon balas dengan angka 1, 2, atau 3. Tim kami sudah bersiap untuk membantu Anda! 🙏"
        5. JIKA PENGGUNA MEMBALAS DENGAN ANGKA 1, 2, ATAU 3 SEBAGAI RESPON DARI MENU CS:
           - Kamu HARUS MENGHUBUNGKAN MEREKA KE TIM MANUSIA dengan menambahkan tag [HANDOVER:X] di AWAL balasanmu (X adalah angka pilihan pengguna 1, 2, atau 3).
           - Contoh balasan: "[HANDOVER:1] Terima kasih kak, mohon tunggu sebentar. Anda sedang dialihkan ke Tim Sekretariat..."
        6. JIKA PENGGUNA MEMILIH LEBIH DARI SATU ANGKA SEKALIGUS (misal: "1 dan 2", "1,2,3"):
           - JANGAN menambahkan tag [HANDOVER:X].
           - Tolak dengan sopan, jelaskan bahwa pengguna hanya dapat memilih 1 (satu) departemen, dan minta mereka memilih ulang satu angka saja.
      PROMPT
    end

    return if ai_endpoint.blank?

    # Prepare chat history
    messages_payload = [{ role: 'system', content: system_prompt + guardrails }]
    
    # Get last 10 messages for context
    recent_messages = conversation.messages.where(message_type: [:incoming, :outgoing]).reorder(created_at: :desc).limit(10).to_a.reverse
    
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
          # Programmatically prepend greeting for the very first message
          if conversation.messages.where(message_type: :outgoing).count == 0
             reply_content = "Salam Budaya! Selamat datang di pusat layanan informasi kami.\n\n" + reply_content
          end

          if match = reply_content.match(/\[HANDOVER:(\d+)\]/i)
            menu_choice = match[1].to_i
            reply_content.gsub!(/\[HANDOVER:\d+\]\s*/i, '')
            
            team_name = case menu_choice
                        when 1 then 'Sekretariat'
                        when 2 then 'Verifikasi'
                        when 3 then 'Pemantauan dan Evaluasi'
                        else nil
                        end
            
            if team_name
              team = account.teams.find_by(name: team_name) || account.teams.find_by("name ILIKE ?", "%#{team_name}%")
              if team
                conversation.update(team_id: team.id)
                conversation.messages.create(
                  message_type: :activity,
                  content: "AI Bot transferred conversation to Team: #{team.name}"
                )
              else
                Rails.logger.error "AI Bot Error: Team #{team_name} not found in account #{account.id}"
                conversation.messages.create(
                  message_type: :activity,
                  content: "AI Bot failed to transfer: Team #{team_name} not found"
                )
              end
            end
          end

          # Create a reply in the conversation
          create_bot_reply(conversation, message, reply_content)
          deduplication.mark_completed
        end
      else
        Rails.logger.error "AI Bot Error: #{response.code} - #{response.body}"
      end
    rescue StandardError => e
      Rails.logger.error "AI Bot Exception: #{e.message}"
    end
  end

  def create_bot_reply(conversation, incoming_message, content)
    ActiveRecord::Base.transaction(requires_new: true) do
      conversation.messages.create!(
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        message_type: :outgoing,
        content: content,
        bot_response_to_message_id: incoming_message.id
      )
    end
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
