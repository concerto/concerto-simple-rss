require 'rexml/document'
require 'xml/xslt'

module Formatters
  class XsltFormatter < BaseFormatter
    def initialize(output_type, blacklisted_tags, xsl)
      super(output_type, blacklisted_tags)
      @xsl = xsl
    end

    def generate_content(feed, title)
      contents = []

      xslt = XML::XSLT.new
      xslt.xml = REXML::Document.new(feed.raw)
      begin
        xslt.xsl = REXML::Document.new(@xsl)
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
          new_content = output_type_instance
          new_content.name = "#{title}"
          new_content.data = sanitize(data)
          contents << new_content if !new_content.data.blank?
        else
          # if there are any content-items then add each one as a separate content
          # and strip off the content-item wrapper
          nodes.each do |n|
            new_content = output_type_instance
            new_content.name = "#{title}"
            new_content.data = sanitize(n.to_s.gsub(/^\s*\<content-item\>/, '').gsub(/\<\/content-item\>\s*$/,''))
            contents << new_content if !new_content.data.blank?
          end
        end
      rescue => e
        # maybe the html was not xml compliant-- this happens frequently in rss feed descriptions
        # look for another separator and use it, if it exists

        if data.present? and data.include?("</content-item>")
          # if there are any content-items then add each one as a separate content
          # and strip off the content-item wrapper
          data.split("</content-item>").each do |n|
            new_content = output_type_instance
            new_content.name = "#{title}"
            new_content.data = sanitize(n.sub("<content-item>", ""))
            contents << new_content if !new_content.data.blank?
          end

        else
          Rails.logger.error("unable to parse resultant xml, assuming it is one content item #{e.message}")
          # raise "unable to parse resultant xml #{e.message}"
          # add the whole result as one content
          new_content = output_type_instance
          new_content.name = "#{title}"
          new_content.data = sanitize(data)
          contents << new_content if !new_content.data.blank?
        end
      end

      contents
    end

    private

    def xslt_replace(nodes, pattern, replacement)
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
          Rails.logger.info "the xsl external function replace does not know how to handle this type #{nodes.class}"
        end
      rescue => e
        Rails.logger.error "there was a problem replacing #{pattern} with #{replacement} - #{e.message}"
      end

      result
    end
  end
end
