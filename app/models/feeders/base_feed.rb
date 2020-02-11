require 'rexml/document'
require 'xml/xslt'

module Feeders
  class BaseFeed
    attr_reader :content, :raw

    def initialize(content, raw = nil)
      @content = content
      @raw = raw
      @title_from_content = nil
      @items = []
    end

    # a collection of title and description entries
    def items
      @items
    end

    def title
      @title_from_content || ''
    end

    def transformable?(stylesheet)
      begin
        xslt = XML::XSLT.new
        xslt.xml = REXML::Document.new(@raw)
        xslt.xsl = REXML::Document.new(stylesheet)
        true
      rescue XML::XSLT::ParsingError
        false
      end
    end

    def type
      'BASE'
    end
  end
end
