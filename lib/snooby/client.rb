module Snooby
  
  # Interface through which Snooby does all of its interacting with the API.
  class Client
    attr_reader :uh, :id

    def initialize(user_agent = "Snooby, #{rand}")
      # Net::HTTP's default User-Agent, "Ruby", is banned on reddit due to its
      # frequent improper use; cheers to Eric Hodel (drbrain) for implementing
      # this workaround for net-http-persistent.
      Conn.override_headers['User-Agent'] = user_agent

      # Allows Snooby's classes to access the currently active client, even if
      # it has not been authorized, allowing the user to log in mid-execution.
      Snooby.active = self
    end

    # Causes the client to be recognized as the given user during API calls.
    # GET operations do not need to be authorized, so if your intent is simply
    # to gather data, feel free to disregard this method entirely.
    def authorize!(user, passwd, force_update = false)
      if Snooby.config['auth'][user] && !force_update
        # Authorization data exists, skip login and potential rate-limiting.
        @uh, @cookie, @id = Snooby.config['auth'][user]
      else
        data = {:user => user, :passwd => passwd}
        json = Snooby.request(Paths[:login] % user, data)['json']
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
    end

    # Returns a User object through which all relevant data is accessed.
    def user(name)
      User.new name
    end

    # Returns a Subreddit object through which all relevant data is accessed.
    # Supplying no name provides access to the client's front page.
    def subreddit(name = nil)
      Subreddit.new name
    end

    def domain(name)
      Domain.new name
    end

    # Returns a hash containing the values given by me.json, used internally to
    # obtain the client's id, but also the most efficient way to check whether
    # or not the client has mail.
    def me
      Snooby.request(Paths[:me])['data']
    end

    # Returns an array of structs containing the current client's saved posts.
    def saved(count = 25)
      Snooby.build Post, :saved, nil, count
    end

    def submit(name, title, content)
      Subreddit.new(name).submit title, content
    end

    def subscribe(name)
			Subreddit.new(name).subscribe
		end

    def unsubscribe(name)
			Subreddit.new(name).unsubscribe
		end

    def friend(name)
			User.new(name).friend
		end

    def unfriend(name)
			User.new(name).unfriend
		end

    def compose(to, subject, text)
      data = {:to => to, :subject => subject, :text => text}
      Snooby.request Paths[:compose], data
    end

    # Aliases all in one place for purely aesthetic reasons.
    alias :u       :user
    alias :r       :subreddit
    alias :sub     :subscribe
    alias :unsub   :unsubscribe
    alias :message :compose
  end
end