function initializeSimpleRSSPreview() {
  // When changes are made to url input, get rss data and build preview
  $('#simple_rss_config_url').keyup(function (e) {
    rss_url = $('#simple_rss_config_url').val();
    getRSSData(rss_url);
  });
}

function getRSSData(rss_url) {
  // Get the rss data based in input url
  $.ajax({
    type: "GET",
    dataType: 'jsonp',
    url: document.location.protocol + '//ajax.googleapis.com/ajax/services/feed/load?v=1.0&num=1000&callback=?&q=' + encodeURIComponent(rss_url),
    success: function (rss_data) {
      simpleRSSPreview(rss_data);
    },
    error: function () {
      $('#preview_div').html("Could not load preview")
    }
  });
}

function simpleRSSPreview(rss_data) {

  // Store all article entries and clear preview 
  articles = rss_data['responseData']['feed']['entries'];
  $('#preview_div').html();

  // Build rss preview for only a sample of article titles
  rss_preview = "<div><p style='font-weight: bold'>Found " + articles.length + " articles total</p></div>";
  for (var i = 0; i < 4; i++) {
    rss_preview += "<div>" +
      "<p style='font-size: 14px; text-decoration: underline'>" + articles[i]['title'] + "</p>" +
      "<p>" + articles[i]['contentSnippet'] + "</p>" + "</div>";
  }
  $('#preview_div').html(rss_preview);
}

$(document).ready(initializeSimpleRSSPreview);
$(document).on('page:change', initializeSimpleRSSPreview);