rag_bot = RagBot.find(2)
rag_bot.update!(use_general_ai_setting: true)
puts "Updated bot! use_general_ai_setting: #{rag_bot.use_general_ai_setting}"
