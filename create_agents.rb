account = Account.first
password = 'Indoraya@2026'

users_data = [
  { email: 'sekre1@indoraya.com', name: 'Sekre 1', team_name: 'Sekre' },
  { email: 'verif1@indoraya.com', name: 'Verifikasi 1', team_name: 'Verifikasi' },
  { email: 'pantau1@indoraya.com', name: 'Pemantauan 1', team_name: 'Pemantauan' }
]

users_data.each do |data|
  user = User.find_by(email: data[:email])
  unless user
    user = User.new(
      email: data[:email],
      password: password,
      password_confirmation: password,
      name: data[:name]
    )
    user.skip_confirmation!
    user.save!(validate: false)
  end

  # Add to account as agent
  unless AccountUser.exists?(account: account, user: user)
    AccountUser.create!(account: account, user: user, role: :agent)
  end

  # Find or create team
  team = account.teams.find_or_create_by!(name: data[:team_name])

  # Add user to team
  unless TeamMember.exists?(team: team, user: user)
    TeamMember.create!(team: team, user: user)
  end
end

puts "Users and teams created successfully!"
