class AiBotListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]
    return unless message.webhook_sendable?

    # trigger the AI job. The job will verify if AI is enabled.
    AiBotReplyJob.perform_later(message.id)
  end
end
