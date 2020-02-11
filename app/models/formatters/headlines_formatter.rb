module Formatters
  class HeadlinesFormatter < BaseFormatter
    def generate_content(feed_items, title)
      contents = []
      feed_items.each_slice(5).with_index do |items, index|
        new_content = output_type_instance
        new_content.name = "#{title} (#{index+1})"
        new_content.data = sanitize("<h1>#{title}</h1> #{items_to_html(items)}")
        contents << new_content
      end
      contents
    end
  end
end
