module Formatters
  class BaseFormatter
    def initialize(output_type, blacklisted_tags)
      @blacklisted_tags = blacklisted_tags
      #@feed = feed
      @output_type = output_type
    end

    def output_type_instance
      @output_type == 'Ticker' ? Ticker.new : HtmlText.new
    end

    def item_to_html(item)
      "<h1>#{item.title}</h1><p>#{item.description.html_safe}</p>"
    end

    def items_to_html(items)
      items.collect { |item| "<h2>#{item.title}</h2>" }.join(" ")
    end

    def sanitize(html)
      if @blacklisted_tags.present?
        whitelist = ActionView::Base.sanitized_allowed_tags
        html = ActionController::Base.helpers.sanitize(html, :tags => (whitelist - @blacklisted_tags))
      end
      html
    end
  end
end
