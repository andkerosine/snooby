module Snooby
  class Subreddit
    include About, Posts, Comments, Compose

    def initialize(name)
      @name = name
      @kind = 'subreddit'
    end

    # Alas, (un)subscribing by name alone doesn't work, so a separate call must
    # be made to obtain the subreddit's id, thus the wait. Maybe cache this?
    def subscribe
      sr = about['name']
      Snooby.wait
      Snooby.request(Paths[:subscribe], :action => 'sub', :sr => sr)
    end
    alias :sub :subscribe

    def unsubscribe
      sr = about['name']
      Snooby.wait
      Snooby.request(Paths[:subscribe], :action => 'unsub', :sr => sr)
    end
    alias :unsub :unsubscribe
  end
end