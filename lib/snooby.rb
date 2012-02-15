%w[net/http/persistent json].each { |d| require d }

module Snooby
  # Opens a persistent connection that provides a significant speed improvement
  # during repeated calls; reddit's rate limit nullifies this for the most part,
  # but it's still a nice library and persistent connections are a Good Thing.
  Conn = Net::HTTP::Persistent.new('snooby')

  # Provides a mapping of things and actions to their respective URL fragments.
  # A path is eventually used as a complete URI, thus the merge.
  paths = {
    :comment            => 'api/comment',
    :login              => 'api/login/%s',
    :me                 => 'api/me.json',
    :subreddit_about    => 'r/%s/about.json',
    :subreddit_comments => 'r/%s/comments.json',
    :subreddit_posts    => 'r/%s.json',
    :user               => 'user/%s',
    :user_about         => 'user/%s/about.json',
    :user_comments      => 'user/%s/comments.json',
    :user_posts         => 'user/%s/submitted.json',
  }
  Paths = paths.merge(paths) { |k, v| 'http://www.reddit.com/' + v }

  # Provides a mapping of things to a list of all the attributes present in the
  # relevant JSON object. A lot of these probably won't get used too often, but
  # might as well expose all available data.
  Fields = {
    :comment => %w[author author_flair_css_class author_flair_text body body_html created created_utc downs id likes link_id link_title name parent_id replies subreddit subreddit_id ups],
    :post    => %w[author author_flair_css_class author_flair_text clicked created created_utc domain downs hidden id is_self likes media media_embed name num_comments over_18 permalink saved score selftext selftext_html subreddit subreddit_id thumbnail title ups url]
  }

  # The crux of Snooby. Generates an array of structs from the Paths and Fields
  # hashes defined above. In addition to just being a very neat container, this
  # allows accessing the returned JSON values using thing.attribute, as opposed
  # to thing['data']['attribute']. Only used for listings of posts and comments
  # at the moment, but I imagine it'll be used for moderation down the road.
  def self.build(object, path, which)
    # A bit of string manipulation to determine which fields to populate the
    # generated struct with. There might be a less fragile way to go about it,
    # but it shouldn't be a problem as long as naming remains consistent.
    kind = object.to_s.split('::')[1].downcase.to_sym

    # Having to explicitly pass the path symbol isn't exactly DRY, but deriving
    # it from the object parameter (say, Snooby::Comment) doesn't expose which
    # kind of comment it is, either User or Post.
    uri = URI(Paths[path] % which)

    # This'll likely have to be tweaked to handle other types of listings, but
    # it's sufficient for comments and posts.
    JSON.parse(Conn.request(uri).body)['data']['children'].map do |child|
      # Maps each of the listing's children to the relevant struct based on the
      # object type passed in. The symbols in a struct definition are ordered,
      # but Python dictionaries are not, so #values isn't sufficient.
      object.new(*child['data'].values_at(*Fields[kind]))
    end
  end

  class << self
    attr_accessor :config, :auth
  end

  # Used for permanent storage of preferences and authorization data.
  # Each client should have its own directory to prevent pollution.
  @config = JSON.parse(File.read('.snooby')) rescue {'auth' => {}}

  # Raised with a pretty print of the relevant JSON object whenever an API call
  # returns a non-empty "errors" field. Where "pretty" is inapplicable, such as
  # when the returned JSON object is a series of jQuery calls, a manual message
  # is displayed instead, typically to inform the user either that they've been
  # rate-limited or that they lack the necessary authorization.
  class RedditError < StandardError; end
end

# Snooby's parts are required down here, after its initial declaration, because
# Post and Comment are structs whose definitions are taken from the Fields hash
# above, and related bits might as well be kept together.
%w[client actions objects].each do |d|
  require "snooby/#{d}"
end