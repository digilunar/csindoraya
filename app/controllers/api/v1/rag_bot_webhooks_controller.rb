require 'net/http'
require 'uri'

class Api::V1::RagBotWebhooksController < ActionController::API
  def create
    @rag_bot = RagBot.find_by!(webhook_token: params[:webhook_token])
    
    # Payload from Chatwoot AgentBot webhook
    payload = request.request_parameters

    return head :ok unless payload['message_type'] == 'incoming' && payload['content'].present?

    ai_reply = nil

    if @rag_bot.use_general_ai_setting && @rag_bot.account.custom_ai_integration.present?
      ai_setting = @rag_bot.account.custom_ai_integration
      uri = URI.parse(ai_setting.endpoint_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.read_timeout = 180

      req = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
      req['Authorization'] = "Bearer #{ai_setting.api_key}" if ai_setting.api_key.present?

      system_prompt = ai_setting.system_prompt.presence || 'Anda adalah asisten virtual yang membantu.'
      bot_knowledge_entries = @rag_bot.rag_knowledge_entries.map(&:answer).uniq.join("\n\n")
      if bot_knowledge_entries.present? || @rag_bot.rag_knowledge.present?
        system_prompt += "\n\nKonteks Pengetahuan:\n"
        system_prompt += "#{@rag_bot.rag_knowledge}\n" if @rag_bot.rag_knowledge.present?
        system_prompt += "\n#{bot_knowledge_entries}\n" if bot_knowledge_entries.present?
        system_prompt += "\nJawab pertanyaan hanya berdasarkan konteks di atas."
      end

      system_prompt += "\n\nATURAN KETAT (GUARDRAILS):\n"
      system_prompt += "1. Anda adalah asisten virtual untuk #{@rag_bot.name}. Tugas Anda HANYA memberikan jawaban langsung dan tuntas berdasarkan teks Konteks Pengetahuan di atas.\n"
      system_prompt += "2. Anda WAJIB memberikan jawaban akhir dalam format JSON murni dengan struktur: {\"status\": \"RELEVAN\" | \"TIDAK_RELEVAN\", \"reply\": \"Jawaban Anda\"}.\n"
      system_prompt += "3. Jika pertanyaan melenceng, set status ke TIDAK_RELEVAN dan kosongkan reply.\n"
      system_prompt += "4. Jika relevan, set status ke RELEVAN dan tulis jawaban di dalam reply tanpa embel-embel.\n"
      system_prompt += "5. DILARANG KERAS menutup pesan dengan pertanyaan seperti 'Ada yang bisa saya bantu?' atau membuat daftar opsi menu layanan. Cukup jawab inti pertanyaannya saja.\n"
      system_prompt += "6. Gunakan format Markdown murni (* atau -) untuk list. JANGAN PERNAH menyebutkan bahwa Anda adalah AI atau Language Model.\n"

      messages_payload = [
        { role: 'system', content: system_prompt }
      ]

      conversation_id = payload.dig("conversation", "id")
      if conversation_id
        conversation = @rag_bot.account.conversations.find(conversation_id)
        # Ambil memori 4 pesan terakhir sebelum pesan saat ini
        recent_messages = conversation.messages.where.not(message_type: 'activity')
                                      .where('id < ?', payload['id'] || 999999999)
                                      .order(created_at: :asc).last(4)
        
        recent_messages.each do |msg|
          next if msg.content.blank?
          role = msg.message_type == 'incoming' ? 'user' : 'assistant'
          messages_payload << { role: role, content: msg.content }
        end
      end

      user_prompt = "Pertanyaan Saat Ini: #{payload['content']}"
      user_prompt += "\n\n[ATURAN KETAT MEMBALAS (WAJIB JSON MURNI)]\n"
      user_prompt += "Anda dilarang keras memulai jawaban dengan sapaan seperti 'Hai' atau 'Selamat datang'. Langsung ke intinya.\n"
      user_prompt += "Jika pertanyaan BISA DIJAWAB menggunakan Konteks: {\"status\": \"RELEVAN\", \"reply\": \"Jawaban faktual Anda dari konteks\"}\n"
      user_prompt += "Jika pertanyaan MELENCENG atau TIDAK ADA di Konteks: {\"status\": \"TIDAK_RELEVAN\", \"reply\": \"\"}\n"
      user_prompt += "JANGAN tambahkan teks di luar JSON."

      messages_payload << { role: 'user', content: user_prompt }

      req.body = {
        model: ai_setting.ai_model,
        stream: false,
        messages: messages_payload
      }.to_json

      begin
        response = http.request(req)
        parsed_response = JSON.parse(response.body) rescue nil
        Rails.logger.info "RagBotWebhook Response: #{response.body}"
        if parsed_response && parsed_response.dig('choices', 0, 'message', 'content')
          raw_ai_reply = parsed_response.dig('choices', 0, 'message', 'content').to_s.strip
          # Hilangkan markdown backticks jika AI bandel
          raw_ai_reply = raw_ai_reply.gsub(/^```json/, '').gsub(/```$/, '').strip
          
          begin
            json_reply = JSON.parse(raw_ai_reply)
            if json_reply['status'].to_s.upcase == 'TIDAK_RELEVAN'
              ai_reply = "Mohon maaf kak, untuk saat ini saya hanya bisa membantu menjawab pertanyaan seputar layanan kami saja. Apakah ada hal lain terkait layanan kami yang bisa dibantu?"
            else
              ai_reply = json_reply['reply']
            end
          rescue JSON::ParserError
            # Fallback if AI fails to return valid JSON
            ai_reply = raw_ai_reply
          end
        elsif parsed_response && parsed_response['error']
          Rails.logger.error "RagBotWebhook API Error: #{parsed_response['error']}"
        end
      rescue => e
        Rails.logger.error "RagBotWebhook General AI Error: #{e.message}"
      end
    elsif @rag_bot.ai_endpoint_url.present?
      # Fallback to custom payload for manual endpoints
      ai_payload = {
        chatwoot_payload: payload,
        rag_knowledge: @rag_bot.rag_knowledge,
        bot_name: @rag_bot.name
      }

      uri = URI.parse(@rag_bot.ai_endpoint_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.read_timeout = 180

      req = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
      req.body = ai_payload.to_json

      begin
        response = http.request(req)
        parsed_response = JSON.parse(response.body) rescue nil
        if parsed_response && parsed_response["content"].present?
          raw_ai_reply = parsed_response["content"].to_s.strip
          raw_ai_reply = raw_ai_reply.gsub(/^```json/, '').gsub(/```$/, '').strip
          
          begin
            json_reply = JSON.parse(raw_ai_reply)
            if json_reply['status'].to_s.upcase == 'TIDAK_RELEVAN'
              ai_reply = "Mohon maaf kak, untuk saat ini saya hanya bisa membantu menjawab pertanyaan seputar layanan kami saja. Apakah ada hal lain terkait layanan kami yang bisa dibantu?"
            else
              ai_reply = json_reply['reply']
            end
          rescue JSON::ParserError
            ai_reply = raw_ai_reply
          end
        end
      rescue => e
        Rails.logger.error "RagBotWebhook Custom Error: #{e.message}"
      end
    end

    if ai_reply.present?
      conversation_id = payload.dig("conversation", "id")
      if conversation_id
        conversation = @rag_bot.account.conversations.find(conversation_id)
        conversation.messages.create!(
          content: ai_reply,
          message_type: :outgoing,
          account_id: @rag_bot.account_id
        )
      end
    end

    head :ok
  end
end
