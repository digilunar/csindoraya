puts "Inbox 2:"
puts Inbox.find_by(id: 2).inspect
puts "Account 1 Inboxes:"
puts Account.find_by(id: 1)&.inboxes&.pluck(:id, :name).inspect
puts "AgentBots:"
puts AgentBot.all.pluck(:id, :name).inspect
