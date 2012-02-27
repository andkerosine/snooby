module Snooby
  
  class User
    include About, Posts, Comments, Compose

    def initialize(name)
      @name = name
      @kind = 'user'
    end

    # Returns an array of arrays containing the user's trophy information in
    # the form of [name, description], the latter containing the empty string
    # if inapplicable.
    def trophies
      # Only interested in trophies; request the minimum amount of content.
      html = Snooby.request(Paths[:user] % @name + '?limit=1', 'html')
      # Entry-level black magic.
      html.scan /"trophy-name">(.+?)<.+?"\s?>([^<]*)</
    end

    def karma_breakdown
      html = Snooby.request(Paths[:user] % @name + '?limit=1', 'html')
      rx = /h>(.+?)<.+?(\d+).+?(\d+)/
      Hash[html.split('y>')[2].scan(rx).map { |r| [r.shift, r.map(&:to_i)] }]
    end

    def liked(count = 25)
      Snooby.build Post, :liked, @name, count
    end

    def disliked(count = 25)
      Snooby.build Post, :disliked, @name, count
    end

    def hidden(count = 25)
      Snooby.build Post, :hidden, @name, count
    end

    def friend(un = '')
      data = {:name => @name, :type => 'friend', :container => Snooby.active.id}
      Snooby.request Paths[:"#{un}friend"], data
    end

    def unfriend
      friend 'un'
    end
  end
end