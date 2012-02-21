module Snooby
  class User
    include About, Posts, Comments, Compose

    def initialize(name)
      @name = name
      @kind = 'user'
    end

    # Returns an array of 2-tuples containing the user's trophy information in
    # the form of [name, description], the latter containing the empty string
    # if inapplicable.
    def trophies
      # Only interested in trophies; request the minimum amount of content.
      html = Snooby.request(URI(Paths[:user] % @name) + '?limit=1')
      # Entry-level black magic.
      html.scan(/"trophy-name">(.+?)<.+?"\s?>([^<]*)</)
    end

    def liked(count = 25)
      Snooby.build(Post, :liked, @name, count)
    end

    def disliked(count = 25)
      Snooby.build(Post, :disliked, @name, count)
    end

    def hidden(count = 25)
      Snooby.build(Post, :hidden, @name, count)
    end

    def friend
      raise RedditError, 'You are not logged in.' unless Snooby.active

      data = {:name => @name, :type => 'friend', :container => Snooby.active.id}
      Snooby.request(Paths[:friend], data)
    end

    def unfriend
      raise RedditError, 'You are not logged in.' unless Snooby.active

      data = {:name => @name, :type => 'friend', :container => Snooby.active.id}
      Snooby.request(Paths[:unfriend], data)
    end
  end
end