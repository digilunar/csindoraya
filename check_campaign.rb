campaign = Campaign.last
puts "Campaign ID: #{campaign.id} | Status: #{campaign.campaign_status} | Scheduled At: #{campaign.scheduled_at} | Audience: #{campaign.audience.inspect} | Template Params: #{campaign.template_params.inspect}"
