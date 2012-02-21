%w[net/http/persistent json].each { |d| require d }

module Snooby
  # Opens a persistent connection that provides a significant speed improvement
  # during repeated calls; reddit's two-second rule pretty much nullifies this,
  # but it's still a great library and persistent connections are a Good Thing.
  Conn = Net::HTTP::Persistent.new('snooby')

  # Provides a mapping of things and actions to their respective URL fragments.
  # A path is eventually used as a complete URI, thus the merge.
  paths = {
    :comment            => 'api/comment',
    :compose            => 'api/compose',
    :delete             => 'api/del',
    :disliked           => 'user/%s/disliked.json',
    :friend             => 'api/friend',
    :hidden             => 'user/%s/hidden.json',
    :liked              => 'user/%s/liked.json',
    :login              => 'api/login/%s',
    :me                 => 'api/me.json',
    :post_comments      => 'comments/%s.json',
    :reddit             => '.json',
    :saved              => 'saved.json',
    :subreddit_about    => 'r/%s/about.json',
    :subreddit_comments => 'r/%s/comments.json',
    :subreddit_posts    => 'r/%s.json',
    :subscribe          => 'api/subscribe',
    :unfriend           => 'api/unfriend',
    :user               => 'user/%s',
    :user_about         => 'user/%s/about.json',
    :user_comments      => 'user/%s/comments.json',
    :user_posts         => 'user/%s/submitted.json',
    :vote               => 'api/vote'
  }
  Paths = paths.merge(paths) { |k, v| "http://www.reddit.com/#{v}" }

  # Provides a mapping of things to a list of all the attributes present in the
  # relevant JSON object. A lot of these probably won't get used too often, but
  # might as well grab all available data (except body_html and selftext_html).
  Fields = {
    :comment => %w[author author_flair_css_class author_flair_text body created created_utc downs id likes link_id link_title name parent_id replies subreddit subreddit_id ups],
    :post    => %w[author author_flair_css_class author_flair_text clicked created created_utc domain downs hidden id is_self likes media media_embed name num_comments over_18 permalink saved score selftext subreddit subreddit_id thumbnail title ups url]
  }

  # Wraps the connection created above for both POST and GET requests to ensure
  # that the two-second rule is adhered to. The uri parameter is turned into an
  # actual URI once here instead of all over the place. The client's modhash is
  # always required for POST requests, so it is passed along by default.
  def self.request(uri, data = nil)
    uri = URI(uri)
    if data
      data.merge!(:uh => Snooby.active.uh) if Snooby.active
      post = Net::HTTP::Post.new(uri.path)
      post.set_form_data(data)
    end
    Snooby.wait if @last_request && Time.now - @last_request < 2
    @last_request = Time.now
    Conn.request(uri, post).body
  end

  # The crux of Snooby. Generates an array of structs from the Paths and Fields
  # hashes defined above. In addition to just being a very neat container, this
  # allows accessing the returned JSON values using thing.attribute, as opposed
  # to thing['data']['attribute']. Only used for listings of posts and comments
  # at the moment, but I imagine it'll be used for moderation down the road.
  # Having to explicitly pass the path isn't very DRY, but deriving it from the
  # object (say, Snooby::Comment) doesn't expose which kind of comment it is.
  def self.build(object, path, which, count)
    # A bit of string manipulation to determine which fields to populate the
    # generated struct with. There might be a less fragile way to go about it,
    # but it shouldn't be a problem as long as naming remains consistent.
    kind = object.to_s.split('::')[1].downcase.to_sym

    # Set limit to the maximum of 100 if we're grabbing more than that, give
    # after a truthy value since we stop when it's no longer so, and initialize
    # an empty result set that the generated structs will be pushed into.
    limit, after, results = [count, 100].min, '', []

    # Fetch data until we've met the count or reached the end of the results.
    while results.size < count && after
      uri = Paths[path] % which + "?limit=#{limit}&after=#{after}"
      json = JSON.parse(Snooby.request(uri), :max_nesting => 100)
      json = json[1] if path == :post_comments # skip over the post's data
      json['data']['children'].each do |child|
        # Converts each child's JSON data into the relevant struct based on the
        # kind of object being built. The symbols of a struct definition are
        # ordered, but Python dictionaries are not, so #values is insufficient.
        # Preliminary testing showed that appending one at a time is slightly
        # faster than concatenating the entire page of results and then taking
        # a slice at the end. This also allows for premature stopping if the
        # count is reached before all results have been processed.
        results << object.new(*child['data'].values_at(*Fields[kind]))
        return results if results.size == count
      end
      after = json['data']['after']
    end
    results
  end

  class << self
    attr_accessor :config, :active
  end

  # Used for permanent storage of preferences and authorization data.
  # Each client should have its own directory to prevent pollution.
  @config = JSON.parse(File.read('.snooby')) rescue {'auth' => {}}

  # Called whenever respecting the API is required.
  def self.wait
    sleep 2
  end

  # Raised with a pretty print of the relevant JSON object whenever an API call
  # returns a non-empty "errors" array, typically in cases of rate limiting and
  # missing or inaccurate authorization.
  class RedditError < StandardError; end
end

# Snooby's parts are required down here, after its initial declaration, because
# Post and Comment are structs whose definitions are taken from the Fields hash
# above, and related bits might as well be kept together.
%w[client actions user subreddit post comment].each do |d|
  require "snooby/#{d}"
end