module Feeders
  class FeedItem
    attr_reader :title, :description
    
    def initialize(title, description)
      @title = title
      @description = description
    end
  end
end