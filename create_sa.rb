sa = SuperAdmin.find_or_initialize_by(email: 'cs@indoraya.com')
sa.password = 'Indo@123'
sa.password_confirmation = 'Indo@123'
sa.name = 'Admin' rescue nil
sa.save!
puts 'SuperAdmin created successfully!'