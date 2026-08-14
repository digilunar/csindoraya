class SendReplyJob < ApplicationJob
  queue_as :high
  DELIVERY_LOCK_TIMEOUT = 5.minutes

  CHANNEL_SERVICES = {
    'Channel::TwitterProfile' => ::Twitter::SendOnTwitterService,
    'Channel::TwilioSms' => ::Twilio::SendOnTwilioService,
    'Channel::Line' => ::Line::SendOnLineService,
    'Channel::Telegram' => ::Telegram::SendOnTelegramService,
    'Channel::Whatsapp' => ::Whatsapp::SendOnWhatsappService,
    'Channel::Sms' => ::Sms::SendOnSmsService,
    'Channel::Instagram' => ::Instagram::SendOnInstagramService,
    'Channel::Tiktok' => ::Tiktok::SendOnTiktokService,
    'Channel::Email' => ::Email::SendOnEmailService,
    'Channel::WebWidget' => ::Messages::SendEmailNotificationService,
    'Channel::Api' => ::Messages::SendEmailNotificationService
  }.freeze

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message

    with_delivery_lock(message.id) do
      message.reload
      return if message.source_id.present?

      channel_name = message.conversation.inbox.channel.class.to_s

      return send_on_facebook_page(message) if channel_name == 'Channel::FacebookPage'

      service_class = CHANNEL_SERVICES[channel_name]
      return unless service_class

      service_class.new(message: message).perform
    end
  end

  private

  def send_on_facebook_page(message)
    if message.conversation.additional_attributes['type'] == 'instagram_direct_message'
      ::Instagram::Messenger::SendOnInstagramService.new(message: message).perform
    else
      ::Facebook::SendOnFacebookService.new(message: message).perform
    end
  end

  def with_delivery_lock(message_id)
    key = format(Redis::RedisKeys::MESSAGE_DELIVERY_MUTEX, message_id: message_id)
    token = SecureRandom.uuid
    acquired = false
    acquired = Redis::Alfred.set(key, token, nx: true, ex: DELIVERY_LOCK_TIMEOUT)
    return unless acquired

    yield
  ensure
    Redis::Alfred.delete_if_equals(key, token) if acquired
  end
end
