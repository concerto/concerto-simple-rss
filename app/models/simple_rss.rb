class SimpleRss < DynamicContent

  DISPLAY_NAME = 'RSS Feed'

  validate :validate_config, :validate_feed

  def build_content
    contents = []

    url = self.config['url']
    type, feed_title, rss = fetch_feed(url)
    
    if (["RSS", "ATOM"].include? type) && !feed_title.blank?
      # it is a valid feed
      case self.config['output_format']
      when 'headlines'
        rss.items.each_slice(5).with_index do |items, index|
          htmltext = HtmlText.new()
          htmltext.name = "#{feed_title} (#{index+1})"
          htmltext.data = "<h1>#{feed_title}</h1> #{items_to_html(items, type)}"
          contents << htmltext
        end
      when 'detailed'
        rss.items.each_with_index do |item, index|
          htmltext = HtmlText.new()
          htmltext.name = "#{feed_title} (#{index+1})"
          htmltext.data = item_to_html(item, type)
          contents << htmltext
        end
      else
        raise ArgumentError, 'Unexpected output format for RSS feed.'
      end
    else
      raise ArgumentError, "Unexpected feed format for #{url}."
    end

    return contents
  end

  # fetch the feed, return the type, title, and contents
  def fetch_feed(url)
    require 'rss'
    require 'net/http'

    type = 'UNKNOWN'
    title = ''
    rss = nil

    begin
      feed = Net::HTTP.get_response(URI.parse(url)).body
      rss = RSS::Parser.parse(feed, false, true)
    rescue => e
      # cant parse rss or url is bad
      Rails.logger.debug("unable to fetch or parse feed - #{url}, #{e.message}")
      rss = e.message
    else
      type = rss.feed_type.upcase

      case type
      when "RSS"
        title = rss.channel.title
      when "ATOM"
        title = rss.title.content
      else
        #title = "unknown feed type"
      end
    end

    return type, title, rss
  end

  def item_to_html(item, type)
    case type
    when "RSS"
      title = item.title
      description = item.description
    when "ATOM"
      title = item.title.content

      # seems like the hard way, but the only way I could figure out to get the 
      # contents without it being html encoded.  most likely a prime candidate for optimizing
      require 'rexml/document'
      entry_xml = REXML::Document.new(item.to_s)
      content_html = REXML::XPath.first(entry_xml, "entry/content").text

      description = (item.summary.nil? ? content_html : item.summary.content)
    end

    return "<h1>#{title}</h1><p>#{description.html_safe}</p>"
  end

  def items_to_html(items, type)
    return items.collect {|item| 
      case type
      when "RSS"
        title = item.title
      when "ATOM"
        title = item.title.content
      end

      "<h2>#{title}</h2>" }.join(" ")
  end

  # Simple RSS processing needs a feed URL and the format of the output content.
  def self.form_attributes
    attributes = super()
    attributes.concat([:config => [:url, :output_format]])
  end

  # if the feed is valid we store the title in config
  def validate_feed
    url = self.config['url']
    unless url.blank? 
      Rails.logger.debug("looking up feed title for #{url}")    

      type, title = fetch_feed(url)
      if (["RSS", "ATOM"].include? type) && !title.blank?
        self.config['title'] = title
      else
        errors.add(:config_url, "does not appear to be an RSS feed")
      end
    end
  end

  def validate_config
    if self.config['url'].blank?
      errors.add(:config_url, "can't be blank")
    end
    if !['headlines', 'detailed'].include?(self.config['output_format'])
      errors.add(:config_output_format, "must be Headlines or Articles")
    end
  end
end
