messages = Conversation.last.messages.order(created_at: :asc).last(10)
messages.each do |m|
  puts "ID: #{m.id} | TYPE: #{m.message_type} | CONTENT: #{m.content.inspect}"
end
