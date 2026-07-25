bot = RagBot.first
bot_knowledge_entries = bot.rag_knowledge_entries.map(&:answer).join("\n\n")
puts "Length: #{bot_knowledge_entries.length}"
File.write("/root/chatwoot/sys_prompt_dump.txt", bot_knowledge_entries)
