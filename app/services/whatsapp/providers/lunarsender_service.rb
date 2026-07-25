class Whatsapp::Providers::LunarsenderService < Whatsapp::Providers::BaseService
  def send_message(phone_number, message)
    return unless message.outgoing_content.present?
    
    number = phone_number.to_s
    number = number.start_with?('+') ? number[1..-1] : number

    body = {
      api_key: whatsapp_channel.provider_config['api_key'],
      sender: whatsapp_channel.provider_config['sender'],
      number: number,
      message: message.outgoing_content
    }

    # Many of these simple gateways accept query params via POST or GET
    # Changing to GET to match the user's manual API call URL exactly
    response = HTTParty.get(
      "https://sender.digilunar.com/send-message",
      headers: {
        'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
      },
      query: body
    )
    
    Rails.logger.info "[LUNARSENDER RESPONSE] body: #{response.body}, code: #{response.code}"
    
    process_response(message, response)
  end

  def validate_provider_config?
    # Simple check to ensure api_key and sender exist
    whatsapp_channel.provider_config['api_key'].present? && whatsapp_channel.provider_config['sender'].present?
  end

  def sync_templates
    []
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
