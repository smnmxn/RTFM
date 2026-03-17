module Vcs
  class Error < StandardError; end
  class AuthenticationError < Error; end
  class NotFoundError < Error; end
  class RateLimitError < Error; end
  class ProviderError < Error; end
end
