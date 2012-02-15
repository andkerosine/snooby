module Snooby
  # Interface through which Snooby does all of its interacting with the API.
  class Client
    def initialize(user_agent = 'Snooby')
      # Net::HTTP's default User-Agent, "Ruby", is banned on reddit due to its
      # frequent improper use; cheers to Eric Hodel (drbrain) for implementing
      # this workaround for net-http-persistent.
      Conn.override_headers['User-Agent'] = user_agent
    end

    # Causes the client to be recognized as the given user during API calls.
    # GET operations do not need to be authorized, so if your intent is simply
    # to gather data, feel free to disregard this method entirely.
    def authorize!(user, passwd, force_update = false)
      if Snooby.config['auth'][user] && !force_update
        # Authorization data exists, skip login and potential rate-limiting.
        @modhash, @cookie = Snooby.config['auth'][user]
      else
        uri = URI(Paths[:login] % user)
        post = Net::HTTP::Post.new(uri.path)
        data = {:user => user, :passwd => CGI.escape(passwd), :api_type => 'json'}
        post.set_form_data(data)
        json = JSON.parse(Conn.request(uri, post).body)['json']

        # Will fire for incorrect login credentials and when rate-limited.
        raise RedditError, jj(json) if !json['errors'].empty?

        # Parse authorization data and store it both in the current config, as
        # well as in the configuration file for future use. This works because
        # authorization data is immortal unless the password has changed. The
        # force_update parameter should be enabled if such is the case.
        @modhash, @cookie = json['data'].values
        Snooby.config['auth'][user] = [@modhash, @cookie]
        File.open('.snooby', 'w') { |f| f << Snooby.config.to_json }
      end

      # Sets the reddit_session cookie required for API calls to be recognized
      # as coming from the intended user; uses override_headers to allow for
      # switching the current user mid-execution, if so desired.
      Conn.headers['Cookie'] = "reddit_session=#{@cookie}"

      # Allows Snooby's classes to access the currently authorized client.
      Snooby.auth = @modhash
    end

    # Returns a hash containing the values supplied by me.json.
    def me
      uri = URI(Paths[:me])
      JSON.parse(Conn.request(uri).body)['data']
    end

    # Returns a User object from which posts, comments, etc. can be accessed.
    def user(name)
      User.new(name)
    end

    # As above, so below.
    def subreddit(name)
      Subreddit.new(name)
    end

    alias :u :user
    alias :r :subreddit
  end
end