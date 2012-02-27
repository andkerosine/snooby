module Snooby

  class Comment < Struct.new(*Fields[:comment].map(&:to_sym))
    include Reply, Delete, Voting
    
    def initialize(*)
      super
      @kind = 'comment'
    end
  end
end