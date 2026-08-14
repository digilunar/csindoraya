class AiBotListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]
    return unless message.webhook_sendable?
    return unless message.incoming?
    return unless BotRoutingService.new(conversation: message.conversation).handles?(:custom_ai)

    AiBotReplyJob.set(wait: 10.seconds).perform_later(message.id)
  end
end
