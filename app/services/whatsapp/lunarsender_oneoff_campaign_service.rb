class Whatsapp::LunarsenderOneoffCampaignService
  pattr_initialize [:campaign!]

  def perform
    validate_campaign!
    # marks campaign completed so that other jobs won't pick it up
    campaign.completed!
    process_audience(extract_audience_labels)
    process_manual_numbers(campaign.template_params&.dig('manual_numbers'))
  end

  private

  delegate :inbox, to: :campaign
  delegate :channel, to: :inbox

  def validate_campaign_type!
    raise "Invalid campaign #{campaign.id}" unless whatsapp_campaign? && campaign.one_off?
  end

  def whatsapp_campaign?
    campaign.inbox.inbox_type == 'Whatsapp'
  end

  def validate_campaign_status!
    raise 'Completed Campaign' if campaign.completed?
  end

  def validate_provider!
    raise 'Lunarsender provider required' if channel.provider != 'lunarsender'
  end

  def validate_feature_flag!
    raise 'WhatsApp campaigns feature not enabled' unless campaign.account.feature_enabled?(:whatsapp_campaign)
  end

  def validate_campaign!
    validate_campaign_type!
    validate_campaign_status!
    validate_provider!
    validate_feature_flag!
  end

  def extract_audience_labels
    return [] unless campaign.audience.present?
    
    audience_label_ids = campaign.audience.select { |audience| audience['type'] == 'Label' }.pluck('id')
    campaign.account.labels.where(id: audience_label_ids).pluck(:title)
  end

  def process_contact(contact)
    Rails.logger.info "Processing contact: #{contact.name} (#{contact.phone_number})"

    if contact.phone_number.blank?
      Rails.logger.info "Skipping contact #{contact.name} - no phone number"
      return
    end

    if campaign.message.blank?
      Rails.logger.error "Skipping contact #{contact.name} - no message found for Lunarsender campaign"
      return
    end

    # Process placeholders
    final_message = campaign.message.dup
    final_message.gsub!(/\{nama\}/i, contact.name.to_s)
    final_message.gsub!(/\{nomor\}/i, contact.phone_number.to_s)

    # Send typing indicator and wait
    typing_duration_ms = calculate_typing_duration(final_message)
    send_typing_indicator(contact, typing_duration_ms)
    
    # Wait for the typing duration before sending message
    sleep(typing_duration_ms / 1000.0) if typing_duration_ms > 0

    send_lunarsender_message(contact: contact, message: final_message)
    
    # Wait for delay before moving to next number
    base_delay = campaign.template_params&.dig('delay').to_f
    is_random = campaign.template_params&.dig('is_random_delay')
    max_delay = campaign.template_params&.dig('max_delay').to_f
    
    delay_to_use = 0
    if is_random && max_delay > base_delay
      delay_to_use = rand(base_delay..max_delay)
    else
      delay_to_use = base_delay
    end

    if delay_to_use > 0
      Rails.logger.info "Waiting for #{delay_to_use.round(2)} seconds before next contact..."
      sleep(delay_to_use)
    end
  end

  def process_audience(audience_labels)
    return if audience_labels.blank?
    
    contacts = campaign.account.contacts.tagged_with(audience_labels, any: true)
    Rails.logger.info "Processing #{contacts.count} contacts for Lunarsender campaign #{campaign.id}"

    contacts.each { |contact| process_contact(contact) }

    Rails.logger.info "Lunarsender Campaign #{campaign.id} audience processing completed"
  end
  
  def process_manual_numbers(numbers_str)
    return if numbers_str.blank?
    
    lines = numbers_str.split(/[\n]+/).map(&:strip).reject(&:blank?)
    return if lines.empty?
    
    Rails.logger.info "Processing #{lines.count} manual lines for Lunarsender campaign #{campaign.id}"
    
    lines.each do |line|
      parts = line.split(/[\|,]/, 2).map(&:strip)
      
      if parts.length == 2
        name = parts[0]
        number = parts[1]
      else
        name = "Manual Contact"
        number = parts[0]
      end
      
      next if number.blank?
      
      mock_contact = Struct.new(:name, :phone_number).new(name, number)
      process_contact(mock_contact)
    end
    
    Rails.logger.info "Lunarsender Campaign #{campaign.id} manual numbers processing completed"
  end

  def calculate_typing_duration(message)
    # 50ms per character, min 2000ms, max 15000ms
    duration = message.length * 50
    duration = [duration, 2000].max
    [duration, 15000].min
  end

  def send_typing_indicator(contact, duration_ms)
    number = contact.phone_number.to_s
    number = number.start_with?('+') ? number[1..-1] : number
    
    api_key = channel.provider_config['api_key']
    sender = channel.provider_config['sender']
    
    return unless api_key.present? && sender.present?

    body = {
      api_key: api_key,
      sender: sender,
      number: number,
      typing: true,
      duration: duration_ms
    }

    Rails.logger.info "[LUNARSENDER CAMPAIGN] Sending typing indicator to #{number} for #{duration_ms}ms"

    HTTParty.get(
      "https://sender.digilunar.com/send-typing",
      headers: {
        'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
      },
      query: body
    )
  rescue StandardError => e
    Rails.logger.error "Failed to send typing indicator: #{e.message}"
  end

  def send_lunarsender_message(contact:, message:)
    # We create a mock OutgoingMessage to pass to `send_message`
    # `send_message` in LunarsenderService expects an object that responds to `outgoing_content` and `update!`
    mock_message = Struct.new(:outgoing_content).new(message)
    
    # Let's override update! on the mock_message since the service calls `message.update!`
    def mock_message.update!(**args)
      Rails.logger.info "[LUNARSENDER CAMPAIGN] Mock message update called with: #{args.inspect}"
    end
    
    channel.send_message(contact.phone_number, mock_message)
    
  rescue StandardError => e
    Rails.logger.error "Failed to send Lunarsender message to #{contact.phone_number}: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.first(5).join('\n')}"
    # continue processing remaining contacts
    nil
  end
end
