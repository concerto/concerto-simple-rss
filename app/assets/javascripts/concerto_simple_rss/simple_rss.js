function initializeSimpleRSSPreview() {
  console.log("\ninitialize RSS Preview");
  $('#simple_rss_config_url').keyup(function (e) {
    console.log("Loading Preview...");
    var url = $(this).data('url');
    if (url) {
      var rss_data = $('textarea#simple_rss_config_url').val();
      $("#preview_div").load(url, { data: rss_data, type: "simple_rss" });
    }
  });
}

$(document).ready(initializeSimpleRSSPreview);
$(document).on('page:change', initializeSimpleRSSPreview);