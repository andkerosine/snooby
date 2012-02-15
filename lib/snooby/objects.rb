module Snooby
  class User
    include Actions

    def initialize(name)
      @name = name
      @kind = 'user'
    end
  end

  class Subreddit
    include Actions

    def initialize(name)
      @name = name
      @kind = 'subreddit'
    end
  end

  class Post < Struct.new(*Fields[:post].map(&:to_sym))
    include Actions

    def initialize(*)
      super
      @kind = 'post'
    end
  end

  class Comment < Struct.new(*Fields[:comment].map(&:to_sym))
    include Actions

    def initialize(*)
      super
      @kind = 'comment'
    end
  end
end