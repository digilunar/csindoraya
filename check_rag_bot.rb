puts "RagBot Webhook Token: 66643fbef722e58ffea7328ec46fd4fc"
rag_bot = RagBot.find_by(webhook_token: "66643fbef722e58ffea7328ec46fd4fc")
puts "RagBot found: #{rag_bot.inspect}"
if rag_bot
  puts "Use general AI setting: #{rag_bot.use_general_ai_setting}"
  puts "Custom AI integration: #{rag_bot.account.custom_ai_integration.inspect}"
end
