class BotReplyDeduplicationService
  LOCK_TIMEOUT = 5.minutes
  COMPLETED_TTL = 1.day

  def initialize(conversation_id:, incoming_message_id:)
    @lock_key = format(
      Redis::RedisKeys::BOT_REPLY_MUTEX,
      conversation_id: conversation_id
    )
    @completed_key = format(
      Redis::RedisKeys::BOT_REPLY_COMPLETED,
      conversation_id: conversation_id,
      message_id: incoming_message_id
    )
  end

  def completed?
    Redis::Alfred.exists?(@completed_key)
  end

  def mark_completed
    Redis::Alfred.set(@completed_key, true, ex: COMPLETED_TTL)
  end

  def with_lock
    token = SecureRandom.uuid
    acquired = false
    acquired = Redis::Alfred.set(@lock_key, token, nx: true, ex: LOCK_TIMEOUT)
    return false unless acquired

    yield
    true
  ensure
    Redis::Alfred.delete_if_equals(@lock_key, token) if acquired
  end
end
