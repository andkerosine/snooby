module Snooby
  
  module About
    # Returns a hash containing the calling object's about.json data.
    def about
      Snooby.request(Paths[:"#{@kind}_about"] % @name)['data']
    end
  end

  module Posts
    # Returns an array of structs containing the calling object's posts.
    def posts(count = 25)
      path = @name ? :"#{@kind}_posts" : :reddit
      Snooby.build Post, path, @name, count
    end
    alias :submissions :posts
  end

  module Comments
    # Returns an array of structs containing the calling object's comments.
    # TODO: return more than just top-level comments for posts.
    def comments(count = @kind == 'post' ? 500 : 25)
      # @name suffices for users and subreddits, but a post's name is obtained
      # from its struct; the "t3_" must be removed before making the API call.
      @name ||= self.name[3..-1]
      Snooby.build Comment, :"#{@kind}_comments", @name, count
    end
  end

  module Reply
    # Posts a reply to the calling object, which is either a post or a comment.
    def reply(text)
      Snooby.request Paths[:comment], :parent => self.name, :text => text
    end
  end

  module Delete
    # Deletes the calling object, which is either a post or a comment.
    def delete
      Snooby.request Paths[:delete], :id => self.name
    end
  end

  module Compose
    # Sends a message to the calling object, which is either a subreddit or a
    # user; in the case of the former, this behaves like moderator mail.
    def compose(subject, text)
      to = (@kind == 'user' ? '' : '#') + @name
      data = {:to => to, :subject => subject, :text => text}
      Snooby.request Paths[:compose], data
    end
    alias :message :compose
  end

  module Voting
    def vote(dir)
      Snooby.request Paths[:vote], :id => self.name, :dir => dir
    end

    def upvote
      vote 1
    end

    def rescind
      vote 0
    end

    def downvote
      vote -1
    end
  end
end