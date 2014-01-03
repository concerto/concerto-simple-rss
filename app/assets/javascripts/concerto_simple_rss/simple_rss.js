// function getRSSData(rss_url) {
//   // Get the rss data based in input url
//   $.ajax({
//     type: "GET",
//     dataType: 'jsonp',
//     url: document.location.protocol + '//ajax.googleapis.com/ajax/services/feed/load?v=1.0&num=1000&callback=?&q=' + encodeURIComponent(rss_url),
//     success: function (rss_data) {
//       simpleRSSPreview(rss_data);
//     },
//     error: function () {
//       $('#preview_div').html("Could not load preview")
//     }
//   });
// }

// function simpleRSSPreview(rss_data) {

//   // Store all article entries and clear preview 
//   articles = rss_data['responseData']['feed']['entries'];
//   $('#preview_div').html();

//   // Build rss preview for only a sample of article titles
//   rss_preview = "<div><p style='font-weight: bold'>Found " + articles.length + " articles total</p></div>";
//   for (var i = 0; i < Math.min(4, articles.length); i++) {
//     rss_preview += "<div>" +
//       "<p style='font-size: 14px; text-decoration: underline'>" + articles[i]['title'] + "</p>" +
//       "<p>" + articles[i]['contentSnippet'] + "</p>" + "</div>";
//   }
//   $('#preview_div').html(rss_preview);
// }

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
    output_format = $('select#simple_rss_config_output_format').val();
    max_items = $('input#simple_rss_config_max_items').val();
    if (max_items == '') {
      max_items = '0';
    }
    $("#preview_div").load(url, { data: { url: rss_url, output_format: output_format, max_items: max_items }, type: 'SimpleRss' });
  }
}

var initializedSimpleRssHandlers = false;
function initializeSimpleRssHandlers() {
  if (!initializedSimpleRssHandlers) {
    $('select#simple_rss_config_output_format').on('change', toggleSimpleRssConditionalInputs);
    toggleSimpleRssConditionalInputs();

    // on change of url, display format, reverse_order, max items, and xsl
    $('input#simple_rss_config_url').on('keyup', previewSimpleRss);

    initializedSimpleRssHandlers = true;
  }
}

$(document).ready(initializeSimpleRssHandlers);
$(document).on('page:change', initializeSimpleRssHandlers);