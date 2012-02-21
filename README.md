# What is Snooby?
Snooby is a wrapper around the reddit API written in Ruby. It aims to make automating any part of the reddit experience as simple and clear-cut as possible, while still providing ample functionality.

## Install
    gem install snooby

## Examples

Here's one way you might go about implementing a very simple bot that constantly monitors new comments to scold users of crass language.

```ruby
require 'snooby'

probot = Snooby::Client.new('ProfanityBot, v1.0')
probot.authorize!('ProfanityBot', 'hunter2')

while true
  probot.r('all').comments.each do |com|
    if com.body =~ /(vile|rotten|words)/
      com.reply("#{$&.capitalize} is a terrible word, #{com.author}!")
    end
  end
end
```

That covers most of the core features, but here's a look at a few more in closer detail.

```ruby
reddit = Snooby::Client.new

reddit.user('andrewsmith1986').about['comment_karma'] # => 548027
reddit.u('violentacrez').trophies.size # => 46

reddit.subreddit('askscience').posts[0].selftext # => We see lots of people...
reddit.r('pics').message('Ban imgur.', "Wouldn't that be lulzy?")

frontpage = reddit.r # note the lack of parameters
frontpage.posts[-1].reply('Welcome to the front page.')

# Downvote everything I've ever said. (Note: most of your votes won't count.)
reddit.u('HazierPhonics').comments(1000).each { |c| c.downvote }

# Similarly, upvote everything on the front page of /r/askscience. (Same disclaimer.)
reddit.r('askscience').posts.each { |p| p.upvote }
```

The code is thoroughly documented and is the best place to start with questions.

## TODO

* Moderation
* Much more thorough configuration file
* Granular caching
* Elegant solution to the "more comments" problem