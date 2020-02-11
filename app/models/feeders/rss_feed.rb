module Feeders
  class RssFeed < BaseFeed
    def initialize(content, raw = nil)
      super(content, raw)
      @title_from_content = content.channel.title
    end

    def items
      return @items if @items.present?
      @items = []
      @content.items.each do |item|
        @items << FeedItem.new(item.title, item.description)
      end
      @items
    end

    def type
      'RSS'
    end
  end
end
