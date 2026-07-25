require 'net/http'
require 'uri'
require 'json'

bot = RagBot.first
ai_setting = bot.account.custom_ai_integration
uri = URI.parse(ai_setting.endpoint_url)
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = (uri.scheme == 'https')
req = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
req['Authorization'] = "Bearer #{ai_setting.api_key}" if ai_setting.api_key.present?

system_prompt = ai_setting.system_prompt.presence || 'Anda adalah asisten virtual yang membantu.'
bot_knowledge_entries = bot.rag_knowledge_entries.map(&:answer).join("\n\n")

system_prompt += "\n\nKonteks Pengetahuan:\n"
system_prompt += "#{bot.rag_knowledge}\n" if bot.rag_knowledge.present?
system_prompt += "\n#{bot_knowledge_entries}\n"

system_prompt += "\n\nATURAN KETAT (GUARDRAILS):\n"
system_prompt += "1. Anda adalah asisten virtual untuk #{bot.name}. Tugas Anda HANYA menjawab berdasarkan teks Konteks Pengetahuan di atas.\n"
system_prompt += "2. Anda WAJIB memberikan jawaban akhir dalam format JSON murni dengan struktur: {\"status\": \"RELEVAN\" | \"TIDAK_RELEVAN\", \"reply\": \"Jawaban Anda\"}.\n"
system_prompt += "3. Jika pertanyaan melenceng, set status ke TIDAK_RELEVAN dan kosongkan reply.\n"
system_prompt += "4. Jika relevan, set status ke RELEVAN dan isi reply berdasarkan dokumen.\n"
system_prompt += "5. Gunakan format Markdown murni (* atau -) untuk list. JANGAN PERNAH menggunakan tag HTML (<br>, <li>).\n"
system_prompt += "6. JANGAN PERNAH menyebutkan bahwa Anda adalah AI, Language Model, GPT-4, OpenAI, atau teknologi apapun. Anda adalah Asisten Virtual resmi dari #{bot.name} dan rahasiakan identitas asli Anda.\n"

user_prompt = "Pertanyaan Saat Ini: bagaimanacara membuat bolu?"
user_prompt += "\n\n[SANGAT PENTING: Anda WAJIB membalas HANYA dengan JSON murni tanpa teks pengantar atau penutup apa pun. Gunakan format template berikut:\n"
user_prompt += "Jika relevan: {\"status\": \"RELEVAN\", \"reply\": \"jawaban Anda dari konteks\"}\n"
user_prompt += "Jika tidak relevan: {\"status\": \"TIDAK_RELEVAN\", \"reply\": \"\"}\n"
user_prompt += "]"

messages_payload = [
  { role: 'system', content: system_prompt },
  { role: 'user', content: user_prompt }
]

req.body = {
  model: ai_setting.ai_model,
  stream: false,
  messages: messages_payload
}.to_json

begin
  puts "Sending request..."
  response = http.request(req)
  puts "Status: #{response.code}"
  puts "Response: #{response.body}"
rescue => e
  puts "Error: #{e.message}"
end
