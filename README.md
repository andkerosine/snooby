# What is Snooby?
Snooby is a wrapper around the reddit API written in Ruby. It aims to make automating any part of the reddit experience as simple and clear-cut as possible, while still providing ample functionality.

## Install
    gem install snooby

## Example

Here's one way you might go about implementing a very simple bot that constantly monitors new comments to scold users of crass language.

```ruby
require 'snooby'

probot = Snooby::Client.new('ProfanityBot, v1.0')
probot.authorize!('ProfanityBot', 'hunter2')
while true
  new_comments = probot.r('all').comments
  sleep 2 # Respecting the API is currently manual, will be fixed in future.
  new_comments.each do |com|
    if com.body =~ /(vile|rotten|words)/
      com.reply("#{$&.capitalize} is a terrible word, #{com.author}!")
      sleep 2
    end
  end
  sleep 2
end
```
## Features

Snooby is in the early stages of active development. Most of the code is structure, but there is *some* functionality in place. At the moment, Snooby can:

* grab the first page of comments/posts for a user/subreddit
* grab about data for users and subreddits
* grab trophy data
* reply to comments and posts

## TODO

Pagination
Flesh out errors
Much more thorough configuration file
Granular caching