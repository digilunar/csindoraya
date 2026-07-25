bots = AgentBot.all
bots.each do |bot|
  puts "BOT ID: #{bot.id}, NAME: #{bot.name}, OUTGOING_URL: #{bot.outgoing_url}"
end
