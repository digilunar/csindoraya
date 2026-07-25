u = User.find_by(email: 'cs@indoraya.com')
u.update_column(:type, 'SuperAdmin') if u
puts "Type updated"