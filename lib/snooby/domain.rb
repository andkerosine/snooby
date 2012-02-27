module Snooby

  class Domain
    include Posts

    def initialize(name)
      @name = name
      @kind = 'domain'
    end
  end
end