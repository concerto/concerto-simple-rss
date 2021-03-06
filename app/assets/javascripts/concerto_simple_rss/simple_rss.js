function toggleSimpleRssConditionalInputs() {
  if ($('select#simple_rss_config_output_format').val() == 'xslt') {
    $('div#simple_rss_maxitems').hide();
    $('div#simple_rss_xslmarkup').show();
  } else {
    $('div#simple_rss_maxitems').show();
    $('div#simple_rss_xslmarkup').hide();
  }
}

function previewSimpleRss() {
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
}

var initializedSimpleRssHandlers = false;
function initializeSimpleRssHandlers() {
  if (!initializedSimpleRssHandlers) {
    $('select#simple_rss_config_output_format').on('change', toggleSimpleRssConditionalInputs);
    toggleSimpleRssConditionalInputs();

    // on blur and change of url, display format, reverse_order, max items, and xsl
    // not on keyup (poor man's debouncing technique?)
    $('input#simple_rss_config_url').on('blur', previewSimpleRss);
    $('input#simple_rss_config_url_userid').on('blur', previewSimpleRss);
    $('input#simple_rss_config_url_password').on('blur', previewSimpleRss);
    $('select#simple_rss_config_output_format').on('change', previewSimpleRss);
    $('input#simple_rss_config_max_items').on('blur', previewSimpleRss);
    $('select#simple_rss_config_reverse_order').on('change', previewSimpleRss);
    $('textarea#simple_rss_config_xsl').on('blur', previewSimpleRss);
    $('input#simple_rss_config_sanitize_tags').on('blur', previewSimpleRss);

    initializedSimpleRssHandlers = true;
  }
}

$(document).ready(initializeSimpleRssHandlers);
$(document).on('page:change', initializeSimpleRssHandlers);