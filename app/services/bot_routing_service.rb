class BotRoutingService
  # One conversation has one bot owner. Keep this order stable.
  def initialize(conversation:)
    @conversation = conversation
    @inbox = conversation.inbox
  end

  def handles?(provider)
    active_provider == provider
  end

  private

  attr_reader :conversation, :inbox

  def active_provider
    return :captain if captain_configured?
    return :agent_bot if agent_bot_active?
    return :dialogflow if dialogflow_active?
    return :custom_ai if custom_ai_active?
  end

  def captain_configured?
    inbox.respond_to?(:captain_assistant) && inbox.captain_assistant.present?
  end

  def agent_bot_active?
    conversation.assignee_agent_bot.present? || inbox.agent_bot_inbox&.active?
  end

  def dialogflow_active?
    inbox.hooks.where(app_id: 'dialogflow', status: :enabled).exists?
  end

  def custom_ai_active?
    integration = conversation.account.custom_ai_integration
    integration.present? && integration.endpoint_url.present?
  end
end
