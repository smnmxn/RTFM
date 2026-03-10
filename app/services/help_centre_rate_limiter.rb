class HelpCentreRateLimiter
  def initialize(project)
    @project = project
    @owner = project.user
  end

  def hourly_limit
    @project.help_centre_hourly_limit
  end

  def daily_limit
    @project.help_centre_daily_limit
  end

  def monthly_limit
    @owner.plan_limit(:ai_answers_per_month)
  end

  def allowed?
    !exceeded?
  end

  def exceeded?
    hourly_exceeded? || daily_exceeded? || monthly_exceeded?
  end

  def increment!
    increment_counter(hourly_key, 1.hour)
    increment_counter(daily_key, 24.hours)
    increment_counter(monthly_key, 30.days)
  end

  def retry_after
    hourly_exceeded? ? seconds_until_next_hour : seconds_until_next_day
  end

  def limit_info
    {
      hourly: { count: hourly_count, limit: hourly_limit, exceeded: hourly_exceeded? },
      daily: { count: daily_count, limit: daily_limit, exceeded: daily_exceeded? },
      monthly: { count: monthly_count, limit: monthly_limit, exceeded: monthly_exceeded? }
    }
  end

  private

  def hourly_count
    Rails.cache.read(hourly_key).to_i
  end

  def daily_count
    Rails.cache.read(daily_key).to_i
  end

  def monthly_count
    Rails.cache.read(monthly_key).to_i
  end

  def hourly_exceeded?
    hourly_count >= hourly_limit
  end

  def daily_exceeded?
    daily_count >= daily_limit
  end

  def monthly_exceeded?
    return false if monthly_limit == Float::INFINITY
    monthly_count >= monthly_limit
  end

  def increment_counter(key, ttl)
    Rails.cache.increment(key, 1, expires_in: ttl)
  end

  def hourly_key
    "help_centre:rate_limit:hourly:project_#{@project.id}:#{Time.current.strftime('%Y%m%d%H')}"
  end

  def daily_key
    "help_centre:rate_limit:daily:project_#{@project.id}:#{Time.current.strftime('%Y%m%d')}"
  end

  def monthly_key
    "help_centre:rate_limit:monthly:user_#{@owner.id}:#{Time.current.strftime('%Y%m')}"
  end

  def seconds_until_next_hour
    (60 - Time.current.min) * 60 - Time.current.sec
  end

  def seconds_until_next_day
    Time.current.end_of_day.to_i - Time.current.to_i
  end
end
