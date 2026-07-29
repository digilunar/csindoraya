inbox = Inbox.find_by(name: "CS TEST RUNNING AI")
if inbox && inbox.channel.is_a?(Channel::Whatsapp)
  puts "Inbox ID: #{inbox.id}"
  puts "Provider: #{inbox.channel.provider}"
  puts "Current Config: #{inbox.channel.provider_config.inspect}"
else
  puts "Inbox not found or not a WhatsApp channel"
end
