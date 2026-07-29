user = User.find_by(email: 'cs@indoraya.com')
if user
  user.password = 'Indoraya@2026'
  user.password_confirmation = 'Indoraya@2026'
  user.save!(validate: false)
  puts 'Updated'
else
  user = User.new(email: 'cs@indoraya.com', password: 'Indoraya@2026', password_confirmation: 'Indoraya@2026', name: 'CS Indoraya', type: 'SuperAdmin')
  user.skip_confirmation!
  user.save!(validate: false)
  puts 'Created'
end
