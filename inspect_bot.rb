bot = RagBot.first
if bot
  puts "BOT NAME: #{bot.name}"
  puts "USE GENERAL AI SETTING: #{bot.use_general_ai_setting}"
  puts "AI ENDPOINT URL: #{bot.ai_endpoint_url}"
  puts "CUSTOM AI INTEGRATION: #{bot.account.custom_ai_integration.inspect}"
end
