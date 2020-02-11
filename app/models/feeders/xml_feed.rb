module Feeders
  class XmlFeed < BaseFeed
    def initialize(content, raw = nil)
      super(content, raw)
    end

    def type
      'XML'
    end
  end
end
