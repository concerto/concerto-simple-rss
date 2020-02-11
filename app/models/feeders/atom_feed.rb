require 'rexml/document'

module Feeders
  class AtomFeed < BaseFeed
    def initialize(content, raw = nil)
      super(content, raw)
      @title_from_content = rss.title.content
    end

    def items
      return @items if @items.present?
      @items = []
      @content.items.each do |item|
        entry_xml = REXML::Document.new(item.to_s)
        content_html = ""
        if (first = REXML::XPath.first(entry_xml, "entry/content"))
          content_html = first.text
        end
        description = (item.summary.nil? ? content_html : item.summary.content) || ''
        @items << FeedItem.new(item.title.content, description)
      end
      @items
    end

    def type
      'ATOM'
    end
  end
end
