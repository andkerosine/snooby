module Snooby
  # Interface through which Snooby does all of its interacting with the API.
  class Client
    # Exposes username to raise a proper error in case of an attempt to delete
    # another user's content, modhash (uh) for sending along in the headers on
    # API calls that change state, and id for (un)friending.
    attr_reader :username, :uh, :id

    def initialize(user_agent = "Snooby, #{rand}")
      # Net::HTTP's default User-Agent, "Ruby", is banned on reddit due to its
      # frequent improper use; cheers to Eric Hodel (drbrain) for implementing
      # this workaround for net-http-persistent.
      Conn.override_headers['User-Agent'] = user_agent
    end

    # Causes the client to be recognized as the given user during API calls.
    # GET operations do not need to be authorized, so if your intent is simply
    # to gather data, feel free to disregard this method entirely.
    def authorize!(user, passwd, force_update = false)
      @username = user

      if Snooby.config['auth'][user] && !force_update
        # Authorization data exists, skip login and potential rate-limiting.
        @uh, @cookie, @id = Snooby.config['auth'][user]
      else
        data = {:user => user, :passwd => passwd, :api_type => 'json'}
        resp = Snooby.request(Paths[:login] % user, data)
        json = JSON.parse(resp)['json']

        # Will fire for incorrect login credentials and when rate-limited.
        raise RedditError, jj(json) unless json['errors'].empty?

        # Parse authorization data.
        @uh, @cookie = json['data'].values
      end

      # Sets the reddit_session cookie required for API calls to be recognized
      # as coming from the intended user. Uses override_headers to allow for
      # switching the current user mid-execution, if so desired.
      Conn.override_headers['Cookie'] = "reddit_session=#{@cookie}"

      # A second call is made, if required, to grab the client's id, which is
      # necessary for (un)friending.
      @id ||= "t2_#{me['id']}"

      # Updates the config file to faciliate one-time authorization. This works
      # because the authorization data is immortal unless the password has been
      # changed; enable the force_update parameter if such is the case.
      Snooby.config['auth'][user] = [@uh, @cookie, @id]
      File.open('.snooby', 'w') { |f| f << Snooby.config.to_json }

      # Allows Snooby's classes to access the currently authorized client.
      Snooby.active = self
    end

    # Returns a User object through which all relevant data is accessed.
    def user(name)
      User.new(name)
    end
    alias :u :user

    # Returns a Subreddit object through which all relevant data is accessed.
    def subreddit(name = nil)
      Subreddit.new(name)
    end
    alias :r :subreddit

    # Returns a hash containing the values given by me.json, used internally to
    # obtain the client's id, but also the most efficient way to check whether
    # or not the client has mail.
    def me
      JSON.parse(Snooby.request(Paths[:me]))['data']
    end

    # Returns an array of structs containing the current client's saved posts.
    def saved(count = 25)
      Snooby.build(Post, :saved, nil, count)
    end

    # Convenience methods.

    def friend(name)
      User.new(name).friend
    end

    def unfriend(name)
      User.new(name).unfriend
    end

    def subscribe(name)
      Subreddit.new(name).subscribe
    end
    alias :sub :subscribe

    def unsubscribe(name)
      Subreddit.new(name).unsubscribe
    end
    alias :unsub :unsubscribe

    def compose(to, subject, text)
      data = {:to => to, :subject => subject, :text => text}
      Snooby.request(Paths[:compose], data)
    end
    alias :message :compose
  end
end