config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
if config
  config.value.reject! { |f| f[:name].to_s == 'rag' || f['name'].to_s == 'rag' }
  config.save!
  puts "Fixed InstallationConfig"
end
