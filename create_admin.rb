account = Account.first || Account.create!(name: 'DANA INDONESIA RAYA')
user = User.find_by(email: 'cs@indoraya.com') || User.new(email: 'cs@indoraya.com', name: 'Admin')
user.password = 'Indo@123'
user.password_confirmation = 'Indo@123'
user.skip_confirmation! if user.respond_to?(:skip_confirmation!)
user.save!
AccountUser.find_or_create_by!(account: account, user: user, role: :administrator)
puts "Admin user created successfully!"