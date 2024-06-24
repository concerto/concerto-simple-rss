var ConcertoSimpleRss = {
  _initialized: false,

  toggleSimpleRssConditionalInputs: function () {
    if ($('select#simple_rss_config_output_format').val() == 'xslt') {
      $('div#simple_rss_maxitems').hide();
      $('div#simple_rss_xslmarkup').show();
    } else {
      $('div#simple_rss_maxitems').show();
      $('div#simple_rss_xslmarkup').hide();
    }
  },

  previewSimpleRss: function () {
    var url = $('input#simple_rss_config_url').data('url');
    if (url) {
      rss_url = $('input#simple_rss_config_url').val();
      userid = $('input#simple_rss_config_url_userid').val();
      password = $('input#simple_rss_config_url_password').val();
      output_format = $('select#simple_rss_config_output_format').val();
      max_items = $('input#simple_rss_config_max_items').val();
      reverse_order = $('select#simple_rss_config_reverse_order').val();
      xsl = $('textarea#simple_rss_config_xsl').val();
      sanitize_tags = $('input#simple_rss_config_sanitize_tags').val();
      if (max_items == '') {
        max_items = '0';
      }
      $("#preview_div").load(url, { data: {
        url: rss_url,
        url_userid: userid,
        url_password: password,
        output_format: output_format,
        max_items: max_items,
        reverse_order: reverse_order,
        xsl: xsl,
        sanitize_tags: sanitize_tags
      }, type: 'SimpleRss' });
    }
  },

  initHandlers: function () {
    if (!ConcertoSimpleRss._initialized) {
      $('select#simple_rss_config_output_format').on('change', ConcertoSimpleRss.toggleSimpleRssConditionalInputs);
      ConcertoSimpleRss.toggleSimpleRssConditionalInputs();

      // on blur and change of url, display format, reverse_order, max items, and xsl
      // not on keyup (poor man's debouncing technique?)
      $('input#simple_rss_config_url').on('blur', ConcertoSimpleRss.previewSimpleRss);
      $('input#simple_rss_config_url_userid').on('blur', ConcertoSimpleRss.previewSimpleRss);
      $('input#simple_rss_config_url_password').on('blur', ConcertoSimpleRss.previewSimpleRss);
      $('select#simple_rss_config_output_format').on('change', ConcertoSimpleRss.previewSimpleRss);
      $('input#simple_rss_config_max_items').on('blur', ConcertoSimpleRss.previewSimpleRss);
      $('select#simple_rss_config_reverse_order').on('change', ConcertoSimpleRss.previewSimpleRss);
      $('textarea#simple_rss_config_xsl').on('blur', ConcertoSimpleRss.previewSimpleRss);
      $('input#simple_rss_config_sanitize_tags').on('blur', ConcertoSimpleRss.previewSimpleRss);

      ConcertoSimpleRss._initialized = true;
    }
  }
};

$(document).ready(ConcertoSimpleRss.initHandlers);
$(document).on('turbolinks:load', ConcertoSimpleRss.initHandlers);
