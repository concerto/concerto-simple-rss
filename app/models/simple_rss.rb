class SimpleRss < DynamicContent
  require 'base64'

  DISPLAY_NAME = 'RSS Feed'

  validate :validate_config, :validate_feed

  # Load a configuration hash.
  # Converts the JSON data stored for the content into the configuration.
  # Called during `after_find`.
  def load_config
    j = JSON.load(self.data)

    # decrypt fields
    unless j.blank?
      encrypted_userid = Base64.decode64(j['url_userid_enc']) unless j['url_userid_enc'].blank?
      encrypted_password = Base64.decode64(j['url_password_enc']) unless j['url_password_enc'].blank?

      begin
        j['url_userid'] = (encrypted_userid.blank? ? "" : Encryptor.decrypt(encrypted_userid))
        j['url_password'] = (encrypted_password.blank? ? "" : Encryptor.decrypt(encrypted_password))
      rescue StandardError => ex
        Rails.logger.error("Unable to decrypt credentials for dynamic content id #{id}: #{ex.message}")
        j['url_userid'] = ''
        j['url_password'] = ''
      end
    end

    self.config = j
  end

  # Prepare the configuration to be saved.
  # Compress the config hash back into JSON to be stored in the database.
  # Called during `before_validation`.
  def save_config
    j = self.config.deep_dup

    # encrypt fields
    j['url_userid_enc'] = (j['url_userid'].blank? ? "" : Base64.encode64(Encryptor.encrypt(j['url_userid'])))
    j['url_password_enc'] = (j['url_password'].blank? ? "" : Base64.encode64(Encryptor.encrypt(j['url_password'])))
    j.delete 'url_userid'
    j.delete 'url_password'
    self.data = JSON.dump(j)
  end

  def build_content
    contents = []

    url = self.config['url']
    unless url.blank?
      url_userid = self.config['url_userid']
      url_password = self.config['url_password']
      type, feed_title, rss, raw = fetch_feed(url, url_userid, url_password)

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
          # xslt.serve does always return a string with ASCII-8BIT encoding regardless of what the actual encoding is
          data = data.force_encoding(xslt.xml.encoding) if data

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
              contents << htmltext if !htmltext.data.blank?
            else
              # if there are any content-items then add each one as a separate content
              # and strip off the content-item wrapper
              nodes.each do |n|
                htmltext = HtmlText.new()
                htmltext.name = "#{feed_title}"
                htmltext.data = sanitize(n.to_s.gsub(/^\s*\<content-item\>/, '').gsub(/\<\/content-item\>\s*$/,''))
                contents << htmltext if !htmltext.data.blank?
              end
            end
          rescue => e
            # maybe the html was not xml compliant-- this happens frequently in rss feed descriptions
            # look for another separator and use it, if it exists

            if data.present? and data.include?("</content-item>")
              # if there are any content-items then add each one as a separate content
              # and strip off the content-item wrapper
              data.split("</content-item>").each do |n|
                htmltext = HtmlText.new()
                htmltext.name = "#{feed_title}"
                htmltext.data = sanitize(n.sub("<content-item>", ""))
                contents << htmltext if !htmltext.data.blank?
              end

            else
              Rails.logger.error("unable to parse resultant xml, assuming it is one content item #{e.message}")
              # raise "unable to parse resultant xml #{e.message}"
              # add the whole result as one content
              htmltext = HtmlText.new()
              htmltext.name = "#{feed_title}"
              htmltext.data = sanitize(data)
              contents << htmltext if !htmltext.data.blank?
            end
          end
        else
          raise ArgumentError, 'Unexpected output format for RSS feed.'
        end
      elsif type == "ERROR"
        raise rss
      else
        Rails.logger.error("could not fetch #{type} feed for #{feed_title} at #{url}")
        raise "Unexpected feed format for #{url}."
      end
    end

    return contents
  end

  def xslt_replace(nodes, pattern, replacement)
    #Rails.logger.debug("pattern = #{pattern}")
    #Rails.logger.debug("replacement = #{replacement}")
    result = []
    begin
      # this will only work with nodesets for now
      re_pattern = Regexp.new(pattern, Regexp::MULTILINE)
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
  def fetch_feed(url, url_userid, url_password)
    require 'encryptor'
    require 'rss'
    require 'open-uri'

    type = 'UNKNOWN'
    title = ''
    rss = nil
    feed = nil

    unless url.blank?
      begin
        # cache same url for 1 minute to alleviate redundant calls when previewing
        feed = Rails.cache.fetch(url, :expires_in => 1.minute) do
          if url_userid.blank? or url_password.blank?
            open(url).read()
          else
            open(url, http_basic_authentication: [url_userid, url_password]).read()
          end
        end

        rss = RSS::Parser.parse(feed, false, true)
        raise "feed could not be parsed" if rss.nil?
      rescue => e
        # cant parse rss or url is bad
        Rails.logger.debug("unable to fetch or parse feed - #{url}, #{e.message}")
        rss = e.message
        type = "ERROR"
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
      content_html = ""
      if (first = REXML::XPath.first(entry_xml, "entry/content"))
        content_html = first.text
      end

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
    attributes.concat([:config => [:url, :url_userid, :url_password, :output_format, :reverse_order, :max_items, :xsl, :sanitize_tags]])
  end

  # if the feed is valid we store the title in config
  def validate_feed
    url = self.config['url']
    url_userid = self.config['url_userid']
    url_password = self.config['url_password']
    unless url.blank?
      Rails.logger.debug("looking up feed title for #{url}")

      type, title = fetch_feed(url, url_userid, url_password)
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
        url_userid = self.config['url_userid']
        url_password = self.config['url_password']
        unless url.blank?
          require 'rexml/document'
          require 'xml/xslt'

          type, title, rss, raw = fetch_feed(url, url_userid, url_password)
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
      o.config['url_userid'] = data[:url_userid]
      o.config['url_password'] = data[:url_password]
      o.config['output_format'] = data[:output_format]
      o.config['max_items'] = data[:max_items]
      o.config['reverse_order'] = data[:reverse_order]
      o.config['xsl'] = data[:xsl]
      o.config['sanitize_tags'] = data[:sanitize_tags]

      content = o.build_content
      results = content.first.data unless content.blank?
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
