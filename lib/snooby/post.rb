module Snooby
  class Post < Struct.new(*Fields[:post].map(&:to_sym))
    include Comments, Reply, Delete, Voting

    def initialize(*)
      super
      @kind = 'post'
    end
  end
end