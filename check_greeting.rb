bot = RagBot.first
found = false
bot.rag_knowledge_entries.each do |e|
  if e.answer.include?('Selamat datang di layanan virtual')
    puts "FOUND in entry: #{e.id}"
    puts e.answer
    found = true
  end
end
puts "NOT FOUND in entries" unless found

if bot.rag_knowledge.include?('Selamat datang di layanan virtual')
  puts "FOUND in rag_knowledge"
else
  puts "NOT FOUND in rag_knowledge"
end
