bot = RagBot.first
puts "BOT KNOWLEDGE: #{bot.rag_knowledge.inspect}"
puts "ENTRIES COUNT: #{bot.rag_knowledge_entries.count}"
bot.rag_knowledge_entries.each do |e|
  puts "ENTRY: #{e.answer.inspect[0..100]}"
end
