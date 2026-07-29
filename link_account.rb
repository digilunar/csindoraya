user = User.find_by(email: 'cs@indoraya.com')
account = Account.first
if account.nil?
  account = Account.create!(name: 'Indoraya')
end

unless AccountUser.exists?(account: account, user: user)
  AccountUser.create!(account: account, user: user, role: :administrator)
  puts 'User successfully linked to the account.'
else
  puts 'User is already linked to the account.'
end
