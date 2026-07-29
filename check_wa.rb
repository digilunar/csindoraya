Channel::Whatsapp.all.each do |c|
  puts "ID: #{c.id}, Phone: #{c.phone_number}, Provider: #{c.provider}"
  puts "Provider config: #{c.provider_config.inspect}"
end
