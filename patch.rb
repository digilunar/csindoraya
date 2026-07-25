path = '/app/app/controllers/api/v1/rag_bot_webhooks_controller.rb'
content = File.read(path)
content = content.gsub('dan kosongkan reply', 'dan berikan pesan penolakan sopan di dalam reply. ANDA WAJIB MENGGUNAKAN BAHASA YANG SAMA DENGAN BAHASA YANG DIGUNAKAN OLEH USER')
content = content.gsub("if json_reply['status'].to_s.upcase == 'TIDAK_RELEVAN'", "if json_reply['status'].to_s.upcase == 'TIDAK_RELEVAN' && json_reply['reply'].blank?")
File.write(path, content)
