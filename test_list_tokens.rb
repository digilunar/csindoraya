Channel::WebWidget.all.each do |w|
  puts "ID: #{w.id}, TOKEN: #{w.website_token}, INBOX_ID: #{w.inbox.id}"
end
