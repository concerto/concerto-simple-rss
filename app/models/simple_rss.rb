# Handle RSS, ATOM, and XML feeds and turn them into content
class SimpleRss < DynamicContent
  DISPLAY_NAME = 'RSS Feed'

  validate :validate_config, :validate_feed

  # Replace base method to load our configuration hash stored in data into config
  def load_config
    ConfigHelper.new(self).load
  end

  # Prepare the configuration to be saved.
  # Compress the config hash back into JSON to be stored in the database.
  # Called during `before_validation`.
  def save_config
    ConfigHelper.new(self).store
  end

  def build_content
    contents = []

    url = self.config['url']
    unless url.blank?
      url_userid = self.config['url_userid']
      url_password = self.config['url_password']
      feed = Feeders::FeedHelper.new(url, url_userid, url_password).fetch
      if feed.present?
        title = feed.title.present? ? feed.title : name

        if !self.config['reverse_order'].blank? && self.config['reverse_order'] == '1'
          feed.items.reverse! 
        end
        feed_items = feed.items
        if !self.config['max_items'].blank? && self.config['max_items'].to_i > 0
          feed_items = feed_items.first(self.config['max_items'].to_i)
        end

        blacklisted_tags = []
        if self.config.include?('sanitize_tags') and !self.config['sanitize_tags'].empty?
          blacklisted_tags = self.config['sanitize_tags'].split(" ")
        end

        output_type = config['output_type'] || 'HtmlText'
        formatter = case self.config['output_format']
            when 'headlines'
              Formatters::HeadlinesFormatter.new(output_type, blacklisted_tags)
            when 'detailed'
              Formatters::DetailedFormatter.new(output_type, blacklisted_tags)
            when 'xslt'
              Formatters::XsltFormatter.new(output_type, blacklisted_tags, self.config['xsl'])
            end
        if formatter.present?
          contents = formatter.generate_content(self.config['output_format'] == 'xslt' ? feed : feed_items, title)
        else
          raise ArgumentError, 'Unexpected output format for RSS feed.'
        end
      else
        Rails.logger.error("could not fetch feed for #{title} at #{url}")
        raise "Unexpected feed format for #{url}."
      end
    end
    return contents
  end

  # Simple RSS processing needs a feed URL and the format of the output content.
  def self.form_attributes
    attributes = super()
    attributes.concat([:config => [:url, :url_userid, :url_password, :output_format, :output_type, :reverse_order, :max_items, :xsl, :sanitize_tags]])
  end

  # if the feed is valid we store the title in config
  def validate_feed
    url = self.config['url']
    url_userid = self.config['url_userid']
    url_password = self.config['url_password']
    unless url.blank?
      Rails.logger.debug("looking up feed title for #{url}")

      feed = Feeders::FeedHelper.new(url, url_userid, url_password).fetch
      if feed.present?
        self.config['title'] = feed.title unless feed.title.blank?
      else
        errors.add(:base, "URL does not appear to be an RSS or XML feed")
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
        if url.present?
          feed = Feeders::FeedHelper.new(url, url_userid, url_password).fetch
          if feed.present?
            if !feed.transformable?(self.config['xsl'])
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
      o.config['output_type'] = data[:output_type]
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
end
