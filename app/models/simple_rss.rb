class SimpleRss < DynamicContent

  DISPLAY_NAME = 'RSS Feed'

  validate :validate_config

  def build_content
    require 'rss'
    require 'net/http'
    url = self.config['url']
    feed = Net::HTTP.get_response(URI.parse(url)).body

    rss = RSS::Parser.parse(feed, false, true)
    contents = []
    
    feed_title = rss.channel.title

    case self.config['output_format']
    when 'headlines'
      rss.items.each_slice(5).with_index do |items, index|
        htmltext = HtmlText.new()
        htmltext.name = "#{feed_title} (#{index+1})"
        htmltext.data = "<h1>#{feed_title}</h1> #{items_to_html(items)}"
        contents << htmltext
      end
    when 'detailed'
      rss.items.each_with_index do |item, index|
        htmltext = HtmlText.new()
        htmltext.name = "#{feed_title} (#{index+1})"
        htmltext.data = item_to_html(item)
        contents << htmltext
      end
    else
      raise ArgumentError, 'Unexpected output format for RSS feed.'
    end
    return contents
  end

  # get the title of the feed for display on the main tile
  def title
    require 'rss'
    require 'net/http'
    url = self.config['url']
#Rails.logger.debug("looking up feed title for #{url}")    

    # assume the feed is valid at this point
    feed = Net::HTTP.get_response(URI.parse(url)).body
    rss = RSS::Parser.parse(feed, false, true)
    rss.channel.title  
  end

  # make sure the feed title gets saved to the config
  def save_config
    if self.parent.nil?
      self.config['title'] = title
    end 

    super
  end

  # try to determine if the feed is valid by returning its type RSS, ATOM, or UNKNOWN (invalid)
  def feed_type(url)
    type = 'UNKNOWN'

    begin
      require 'rss'
      require 'net/http'
      feed = Net::HTTP.get_response(URI.parse(url)).body

      begin
        rss = RSS::Parser.parse(feed, false, true)
      rescue => e
        # cant parse rss
      else
        type = "RSS"      
      end

      begin
        feed_title = rss.channel.title
      rescue
        # oops, must be atom?
        type = "ATOM"
      end
    rescue
      # bad url?
    end

    type
  end

  def item_to_html(item)
    return "<h1>#{item.title}</h1><p>#{item.description}</p>"
  end

  def items_to_html(items)
    return items.collect{|item| "<h2>#{item.title}</h2>"}.join(" ")
  end

  # Simple RSS processing needs a feed URL and the format of the output content.
  def self.form_attributes
    attributes = super()
    attributes.concat([:config => [:url, :output_format]])
  end

  def validate_config
    if self.config['url'].blank?
      errors.add(:config_url, "can't be blank")
    else
      if feed_type(self.config['url']) != "RSS"
        errors.add(:config_url, "does not appear to be an RSS feed")
      end
    end
    if !['headlines', 'detailed'].include?(self.config['output_format'])
      errors.add(:config_output_format, "must be Headlines or Articles")
    end
  end
end
