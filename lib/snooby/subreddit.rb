module Snooby
  
  class Subreddit
    include About, Posts, Comments, Compose

    def initialize(name)
      @name = name
      @kind = 'subreddit'
    end

    def submit(title, content)
      data = {:title => title, :sr => @name}
      data[:kind] = content[/^https?:/] ? 'link' : 'self'
      data[:"#{$& ? 'url' : 'text'}"] = content
      Snooby.request Paths[:submit], data
    end

    # Alas, (un)subscribing by name alone doesn't work, so a separate call must
    # be made to obtain the subreddit's id, thus the wait. Maybe cache this?
    def subscribe(un = '')
      sr = about['name']
      Snooby.request Paths[:subscribe], :action => "#{un}sub", :sr => sr
    end

    def unsubscribe
      subscribe 'un'
    end

    alias :sub   :subscribe
    alias :unsub :unsubscribe
  end
end