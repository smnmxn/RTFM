module Vcs
  class Provider
    ADAPTERS = {
      github: "Vcs::Github::Adapter",
      bitbucket: "Vcs::Bitbucket::Adapter"
    }.freeze

    def self.for(name)
      key = name.to_sym
      unless ADAPTERS.key?(key)
        raise Vcs::Error, "Unknown VCS provider: #{name}. Supported: #{ADAPTERS.keys.join(', ')}"
      end

      ADAPTERS[key].constantize.new
    end

    def self.supported?(name)
      ADAPTERS.key?(name.to_sym)
    end
  end
end
