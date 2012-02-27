module Snooby
  
  class Post < Struct.new(*Fields[:post].map(&:to_sym))
    include Comments, Reply, Delete, Voting

    def initialize(*)
      super
      @kind = 'post'
    end

    def save(un = '')
      Snooby.request Paths[:"#{un}save"], :id => self.name
    end

    def unsave
      save 'un'
    end

    def hide(un = '')
      Snooby.request Paths[:"#{un}hide"], :id => self.name
    end

    def unhide
      hide 'un'
    end

    def mark(un = '')
      Snooby.request Paths[:"#{un}mark"], :id => self.name
    end

    def unmark
      mark 'un'
    end
  end
end