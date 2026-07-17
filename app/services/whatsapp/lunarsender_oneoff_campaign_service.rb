class Whatsapp::LunarsenderOneoffCampaignService
  pattr_initialize [:campaign!]

  def perform
    validate_campaign!
    # marks campaign completed so that other jobs won't pick it up
    campaign.completed!
    process_audience(extract_audience_labels)
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

    send_lunarsender_message(contact: contact, message: campaign.message)
  end

  def process_audience(audience_labels)
    contacts = campaign.account.contacts.tagged_with(audience_labels, any: true)
    Rails.logger.info "Processing #{contacts.count} contacts for Lunarsender campaign #{campaign.id}"

    contacts.each { |contact| process_contact(contact) }

    Rails.logger.info "Lunarsender Campaign #{campaign.id} processing completed"
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
