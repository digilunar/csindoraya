class Whatsapp::Providers::LunarsenderService < Whatsapp::Providers::BaseService
  def send_message(message)
    return unless message.outgoing_content.present?
    
    number = message.conversation.contact_inbox.source_id
    # Ensure number starts with + or just use the number if it already has country code
    number = number.start_with?('+') ? number[1..-1] : number

    body = {
      api_key: whatsapp_channel.provider_config['api_key'],
      sender: whatsapp_channel.provider_config['sender'],
      number: number,
      message: message.outgoing_content
    }

    response = HTTParty.post(
      "https://sender.digilunar.com/send-message",
      body: body.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    
    process_response(message, response)
  end

  def validate_provider_config?
    # Simple check to ensure api_key and sender exist
    whatsapp_channel.provider_config['api_key'].present? && whatsapp_channel.provider_config['sender'].present?
  end

  private

  def process_response(message, response)
    # The API doesn't specify failure codes clearly, assuming HTTP 200 is success
    if response.success?
      # LunarSender API typically returns JSON but doesn't guarantee a message ID we can track
      # We could parse and save the message ID if available
      if response.parsed_response.is_a?(Hash) && response.parsed_response['id']
        message.update!(source_id: response.parsed_response['id'])
      end
    else
      message.update!(
        status: :failed,
        external_error: "LunarSender Error: #{response.body}"
      )
    end
  end
end
