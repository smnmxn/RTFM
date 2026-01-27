class PresenceChannel < ApplicationCable::Channel
  ONLINE_TTL = 60 # seconds

  def subscribed
    stream_for current_user
    mark_online
  end

  def unsubscribed
    mark_offline
  end

  # Called periodically by the client to keep the presence key alive
  def heartbeat
    mark_online
  end

  private

  def mark_online
    redis.set(redis_key, "1", ex: ONLINE_TTL)
  end

  def mark_offline
    redis.del(redis_key)
  end

  def redis_key
    "user:#{current_user.id}:online"
  end

  def redis
    @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
  end
end
