messages = Conversation.find(52).messages.order(created_at: :asc)
messages.each do |m|
  puts "ID: #{m.id} | TYPE: #{m.message_type} | CONTENT: #{m.content}"
end
