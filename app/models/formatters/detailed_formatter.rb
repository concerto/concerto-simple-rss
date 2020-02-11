module Formatters
  class DetailedFormatter < BaseFormatter
    def generate_content(feed_items, title)
      contents = []
      feed_items.each_with_index do |item, index|
        new_content = output_type_instance
        new_content.name = "#{title} (#{index+1})"
        new_content.data = sanitize(item_to_html(item))
        contents << new_content
      end
      contents
    end
  end
end
