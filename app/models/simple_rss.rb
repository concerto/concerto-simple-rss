class SimpleRss < DynamicContent

  DISPLAY_NAME = 'RSS Feed'

  validate :validate_config, :validate_feed

  def build_content
    contents = []

    url = self.config['url']
    type, feed_title, rss, raw = fetch_feed(url)
    
    if (["RSS", "ATOM"].include? type) && !feed_title.blank?
      # it is a valid feed
      if !self.config['reverse_order'].blank? && self.config['reverse_order'] == '1'
        rss.items.reverse!
      end
      feed_items = rss.items
      if !self.config['max_items'].blank? && self.config['max_items'].to_i > 0
        feed_items = feed_items.first(self.config['max_items'].to_i)
      end
      case self.config['output_format']
      when 'headlines'
        feed_items.each_slice(5).with_index do |items, index|
          htmltext = HtmlText.new()
          htmltext.name = "#{feed_title} (#{index+1})"
          htmltext.data = sanitize("<h1>#{feed_title}</h1> #{items_to_html(items, type)}")
          contents << htmltext
        end
      when 'detailed'
        feed_items.each_with_index do |item, index|
          htmltext = HtmlText.new()
          htmltext.name = "#{feed_title} (#{index+1})"
          htmltext.data = sanitize(item_to_html(item, type))
          contents << htmltext
        end
      when 'xslt'
        require 'rexml/document'
        require 'xml/xslt'

        #XML::XSLT.registerErrorHandler { |string| puts string }
        xslt = XML::XSLT.new()
        begin
          xslt.xml = REXML::Document.new(raw)
        rescue REXML::ParseException => e
          Rails.logger.error("Unable to parse incoming feed: #{e.message}")
          raise "Unable to parse incoming feed. "
        rescue => e
          raise e
        end

        begin
          xslt.xsl = REXML::Document.new(self.config['xsl'])
        rescue REXML::ParseException => e
          Rails.logger.error("Unable to parse Xsl: #{e.message}")
          # fmt is <rexml::parseexception: message :> trace ... so just pull out the message
          s = e.message
          msg_stop = s.index(">")
          s = s.slice(23, msg_stop - 23) if !msg_stop.nil?
          raise "Unable to parse Xsl.  #{s}"
        rescue => e
          raise e
        end

        # add a replace [gsub] function for more powerful transforms.  You can use this in a transform
        # by adding the bogus namespace http://concerto.functions
        # A nodeset comes in as an array of REXML::Elements 
        XML::XSLT.registerExtFunc("http://concerto.functions", "replace") do |nodes, pattern, replacement|
          result = xslt_replace(nodes, pattern, replacement)
          result
        end

        XML::XSLT.registerExtFunc("http://schemas.concerto-signage.org/functions", "replace") do |nodes, pattern, replacement|
          result = xslt_replace(nodes, pattern, replacement)
          result
        end

        data = xslt.serve()

        # try to load the transformed data as an xml document so we can see if there are 
        # mulitple content-items that we need to parse out, if we cant then treat it as one content item
        begin
          data_xml = REXML::Document.new('<root>' + data + '</root>')
          nodes = REXML::XPath.match(data_xml, "//content-item")
          # if there are no content-items then add the whole result (data) as one content
          if nodes.count == 0
            htmltext = HtmlText.new()
            htmltext.name = "#{feed_title}"
            htmltext.data = sanitize(data)
            contents << htmltext
          else
            # if there are any content-items then add each one as a separate content
            # and strip off the content-item wrapper
            nodes.each do |n|
              htmltext = HtmlText.new()
              htmltext.name = "#{feed_title}"
              htmltext.data = sanitize(n.to_s.gsub(/^\s*\<content-item\>/, '').gsub(/\<\/content-item\>\s*$/,''))
              contents << htmltext
            end
          end
        rescue => e
          Rails.logger.error("unable to parse resultant xml, assuming it is one content item #{e.message}")
          # raise "unable to parse resultant xml #{e.message}"
          # add the whole result as one content
          htmltext = HtmlText.new()
          htmltext.name = "#{feed_title}"
          htmltext.data = sanitize(data)
          contents << htmltext
        end
      else
        raise ArgumentError, 'Unexpected output format for RSS feed.'
      end
    else
      Rails.logger.error("could not fetch #{type} feed for #{feed_title} at #{url}")
      raise "Unexpected feed format for #{url}."
    end

    return contents
  end

  def xslt_replace(nodes, pattern, replacement)
    #Rails.logger.debug("pattern = #{pattern}")
    #Rails.logger.debug("replacement = #{replacement}")
    result = []
    begin
      # this will only work with nodesets for now
      re_pattern = Regexp.new(pattern)
      if nodes.is_a?(Array) && nodes.count > 0 && nodes.first.is_a?(REXML::Element)
        nodes.each do |node|
          s = node.to_s
          r = s.gsub(re_pattern, replacement)
          result << REXML::Document.new(r)
        end
      elsif nodes.is_a?(String)
        result = nodes.gsub(re_pattern, replacement)
      else
        # dont know how to handle this
        Rails.logger.info "I'm sorry, but the xsl external function replace does not know how to handle this type #{nodes.class}"
      end
    rescue => e
      Rails.logger.error "there was a problem replacing #{pattern} with #{replacement} - #{e.message}"
    end

    result
  end    

  # fetch the feed, return the type, title, and contents (parsed) and raw feed (unparsed)
  def fetch_feed(url)
    require 'rss'
    require 'net/http'

    type = 'UNKNOWN'
    title = ''
    rss = nil
    feed = nil

    begin
      # cache same url for 1 minute to alleviate redundant calls when previewing
      feed = Rails.cache.fetch(url, :expires_in => 1.minute) do
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        request = Net::HTTP::Get.new(uri.request_uri)
        http.request(request).body
      end

      rss = RSS::Parser.parse(feed, false, true)
      raise "feed could not be parsed" if rss.nil?
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

    return type, title, rss, feed
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

    description ||= ""
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
    attributes.concat([:config => [:url, :output_format, :reverse_order, :max_items, :xsl, :sanitize_tags]])
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
        errors.add(:base, "URL does not appear to be an RSS feed")
      end
    end
  end

  def validate_config
    if self.config['url'].blank?
      errors.add(:base, "URL can't be blank")
    end

    if !['headlines', 'detailed', 'xslt'].include?(self.config['output_format'])
      errors.add(:base, "Display Format must be Headlines or Articles or XSLT")
    end

    if self.config['output_format'] == 'xslt'
      if self.config['xsl'].blank?
        errors.add(:base, "XSL Markup can't be blank when using the XSLT Display Format")
      else
        url = self.config['url']
        unless url.blank? 
          require 'rexml/document'
          require 'xml/xslt'

          type, title, rss, raw = fetch_feed(url)
          if ["RSS", "ATOM"].include? type
            begin
              xslt = XML::XSLT.new()
              xslt.xml = REXML::Document.new(raw)
              xslt.xsl = REXML::Document.new(self.config['xsl'])
            rescue XML::XSLT::ParsingError
              errors.add(:base, "XSL Markup could not be parsed")
            end
          end
        end
      end
    end
  end

  # return the first item for use as a preview
  # data is a hash of the config
  def self.preview(data)
    begin
      o = SimpleRss.create()
      o.config['url'] = data[:url]
      o.config['output_format'] = data[:output_format]
      o.config['max_items'] = data[:max_items]
      o.config['reverse_order'] = data[:reverse_order]
      o.config['xsl'] = data[:xsl]
      o.config['sanitize_tags'] = data[:sanitize_tags]
      results = o.build_content.first.data
    rescue => e
      results = "Unable to preview.  #{e.message}"
    end

    return results
  end

  def sanitize(html)
    if self.config.include?('sanitize_tags') and !self.config['sanitize_tags'].empty?
      whitelist = ActionView::Base.sanitized_allowed_tags 
      blacklist = self.config['sanitize_tags'].split(" ")

      html = ActionController::Base.helpers.sanitize(html, :tags => (whitelist - blacklist))
    end
    html
  end

end
