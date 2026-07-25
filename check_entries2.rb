bot = RagBot.first
found = false
bot.rag_knowledge_entries.each do |e|
  if e.answer.include?('Kualitas jaringan dipengaruhi')
    puts "FOUND IN ENTRY ID #{e.id}"
    found = true
  end
end
puts "NOT FOUND" unless found
