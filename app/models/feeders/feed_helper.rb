require 'rss'
require 'open-uri'

module Feeders
  # Create the relevant feed based on its content.
  class FeedHelper
    attr_reader :url, :url_user, :url_password

    def initialize(url, url_user, url_password)
      @url = url
      @url_user = url_user
      @url_password = url_password
    end

    def fetch
      return if @url.blank?

      instantiate_feed_for(content_from_url)
    end

    private

    def content_from_url
      if @url_user.blank? || @url_password.blank?
        open(@url).read
      else
        open(@url, http_basic_authentication: [@url_user, @url_password]).read
      end
    rescue => exception
      Rails.logger.error("unable to fetch feed - #{@url}, #{exception.message}")
    end

    def instantiate_feed_for(response)
      rss = RSS::Parser.parse(response, false, true)
      if rss.blank?
        doc = REXML::Document.new(response)
        return XmlFeed.new(doc, response) if doc.present?

        raise "unknown content"
      else
        feed_type = rss.feed_type.upcase
        return RssFeed.new(rss, response) if feed_type == 'RSS'
        return AtomFeed.new(rss, response) if feed_type == 'ATOM'

        raise "unknown feed type #{feed_type}"
      end
    rescue => exception
      Rails.logger.error("unable to parse feed - #{@url}, #{exception.message}")
    end
  end
end
