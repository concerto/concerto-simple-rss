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
    end
  end
end
