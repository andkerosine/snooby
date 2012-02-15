module Snooby
  # Mixin to provide functionality to all of the objects in one fell swoop,
  # both relevant and irrelevant. Errors are thrown where nonsensical methods
  # are called, but hopefully the intent is to use Snooby sensibly. I realize
  # this is probably bad design, but it's just so damned clean.
  module Actions
    # Returns a hash containing the values supplied by about.json, so long as
    # the calling object is a User or Subreddit.
    def about
      if !['user', 'subreddit'].include?(@kind)
        raise RedditError, 'Only users and subreddits have about pages.'
      end

      uri = URI(Paths[:"#{@kind}_about"] % @name)
      JSON.parse(Conn.request(uri).body)['data']
    end

    # Returns an array of structs containing the object's posts.
    def posts
      if !['user', 'subreddit'].include?(@kind)
        raise RedditError, 'Only users and subreddits have posts.'
      end

      Snooby.build(Post, :"#{@kind}_posts", @name)
    end

    # Returns an array of structs containing the object's comments.
    def comments
      if !['user', 'subreddit'].include?(@kind)
        raise RedditError, 'Only users and subreddits have comments.'
      end

      Snooby.build(Comment, :"#{@kind}_comments", @name)
    end

    # Returns an array of 2-tuples containing the user's trophy information in
    # the form of [name, description], the latter containing the empty string
    # if inapplicable.
    def trophies
      raise RedditError, 'Only users have trophies.' if @kind != 'user'

      # Only interested in trophies; request the minimum amount of content.
      html = Conn.request(URI(Paths[:user] % @name) + '?limit=1').body
      # Entry-level black magic.
      html.scan(/"trophy-name">(.+?)<.+?"\s?>([^<]*)</)
    end

    # Posts a reply to the caller as the currently authorized user, so long as
    # that caller is a Post or Comment.
    def reply(text)
      raise RedditError, 'You must be authorized to comment.' if !Snooby.auth

      if !['post', 'comment'].include?(@kind)
        raise RedditError, "Replying to a #{@kind} doesn't make much sense."
      end

      uri = URI(Paths[:comment])
      post = Net::HTTP::Post.new(uri.path)
      data = {:parent => self.name, :text => text, :uh => Snooby.auth}
      post.set_form_data(data)
      json = JSON.parse(Conn.request(uri, post).body)['jquery']

      # Bad magic numbers, I know, but getting rate-limited during a reply
      # returns a bunch of serialized jQuery rather than a straightforward
      # and meaningful message. Fleshing out errors is on the to-do list.
      raise RedditError, json[14][3] if json.size == 17
    end
  end
end