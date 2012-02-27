%w[json net/http/persistent].each { |dep| require dep }

CONFIG_FILE = '.snooby/config.json'

# Creates and initializes configuration and caching on a per-directory basis.
# Doesn't update if they already exist, but this might need to be fleshed out
# a bit in future to merge values to be kept with new defaults in upgrades.
unless File.exists? CONFIG_FILE
  DEFAULT_CONFIG = File.join Gem.datadir('snooby'), 'config.json'
  %w[.snooby .snooby/cache].each { |dir| Dir.mkdir dir }
  File.open(CONFIG_FILE, 'w') { |file| file << File.read(DEFAULT_CONFIG) }
end

# reddit API (Snoo) + happy programming (Ruby) = Snooby
module Snooby

  class << self
    attr_accessor :config, :active
  end

  # Raised with a pretty print of the relevant JSON object whenever an API call
  # returns a non-empty "errors" array, typically in cases of rate limiting and
  # missing or insufficient authorization. Also used as a general container for
  # miscellaneous errors related to site functionality.
  class RedditError < StandardError
  end

  # Changes to configuration should persist across multiple uses. This class is
  # a simple modification to the standard hash's setter that updates the config
  # file whenever a value changes.
  class Config < Hash
    def []=(key, value)
      super
      return unless Snooby.config # nil during initialization inside JSON#parse
      File.open(CONFIG_FILE, 'w') do |file|
        file << JSON.pretty_generate(Snooby.config)
      end
    end
  end

  @config = JSON.parse(File.read(CONFIG_FILE), object_class: Config)
  raise RedditError, 'Insufficiently patient delay.' if @config['delay'] < 2

  # Opens a persistent connection that provides a significant speed improvement
  # during repeated calls; reddit's two-second rule pretty much nullifies this,
  # but it's still a great library and persistent connections are a Good Thing.
  Conn = Net::HTTP::Persistent.new 'Snooby'

  paths = {
    :comment            => 'api/comment',
    :compose            => 'api/compose',
    :delete             => 'api/del',
    :disliked           => 'user/%s/disliked.json',
    :domain_posts       => 'domain/%s.json',
    :friend             => 'api/friend',
    :hidden             => 'user/%s/hidden.json',
    :hide               => 'api/hide',
    :liked              => 'user/%s/liked.json',
    :login              => 'api/login/%s',
    :mark               => 'api/marknsfw',
    :me                 => 'api/me.json',
    :post_comments      => 'comments/%s.json',
    :reddit             => '.json',
    :save               => 'api/save',
    :saved              => 'saved.json',
    :submit             => 'api/submit',
    :subreddit_about    => 'r/%s/about.json',
    :subreddit_comments => 'r/%s/comments.json',
    :subreddit_posts    => 'r/%s.json',
    :subscribe          => 'api/subscribe',
    :unfriend           => 'api/unfriend',
    :unhide             => 'api/unhide',
    :unmark             => 'api/unmarknsfw',
    :unsave             => 'api/unsave',
    :user               => 'user/%s',
    :user_about         => 'user/%s/about.json',
    :user_comments      => 'user/%s/comments.json',
    :user_posts         => 'user/%s/submitted.json',
    :vote               => 'api/vote',
  }

  # Provides a mapping of things and actions to their respective URL fragments.
  Paths = paths.merge(paths) { |act, path| "http://www.reddit.com/#{path}" }

  # Provides a mapping of things to a list of all the attributes present in the
  # relevant JSON object. A lot of these probably won't get used too often, but
  # might as well grab all available data (except body_html and selftext_html).
  Fields = {
    :comment => %w[author author_flair_css_class author_flair_text body created created_utc downs id likes link_id link_title name parent_id replies subreddit subreddit_id ups],
    :post    => %w[author author_flair_css_class author_flair_text clicked created created_utc domain downs hidden id is_self likes media media_embed name num_comments over_18 permalink saved score selftext subreddit subreddit_id thumbnail title ups url]
  }

  # Wraps the connection for all requests to ensure that the two-second rule is
  # adhered to. The uri parameter comes in as a string because it may have been
  # susceptible to variables, so it gets turned into an actual URI here instead
  # of all over the place. Since it's required for all POST requests other than
  # logging in, the client's modhash is sent along by default.
  def self.request(uri, data = nil)
    uri = URI uri
    if data && data != 'html'
      unless active.uh || data[:passwd]
        raise RedditError, 'You must be logged in to make POST requests.'
      end
      post = Net::HTTP::Post.new uri.path
      post.set_form_data data.merge!(:uh => active.uh, :api_type => 'json')
    end
    wait if @last_request && Time.now - @last_request < @config['delay']
    @last_request = Time.now

    resp = Conn.request uri, post
    raise ArgumentError, resp.code_type unless resp.code == '200'

    # Raw HTML is parsed to obtain the user's trophy data and karma breakdown.
    return resp.body if data == 'html'
    
    json = JSON.parse resp.body, :max_nesting => 100
    if (resp = json['json']) && (errors = resp['errors'])
      raise RedditError, jj(json) unless errors.empty?
    end
    json
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
    # generated structs with. There might be a less fragile way to go about it,
    # but it shouldn't be a problem as long as naming remains consistent.
    kind = object.to_s.split('::')[1].downcase.to_sym

    # Set limit to the maximum of 100 if we're grabbing more than that, give
    # after a truthy value since we stop when it's no longer so, and initialize
    # an empty result set that the generated structs will be pushed into.
    limit, after, results = [count, 100].min, '', []

    while results.size < count && after
      uri = Paths[path] % which + "?limit=#{limit}&after=#{after}"
      json = request uri
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

  # Called whenever respecting the API is required.
  def self.wait
    sleep @config['delay']
  end
end

# Snooby's parts are required down here, after its initial declaration, because
# Post and Comment are structs whose definitions are taken from the Fields hash
# and related bits might as well be kept together.
%w[client actions user subreddit domain post comment].each do |dep|
  require "snooby/#{dep}"
end