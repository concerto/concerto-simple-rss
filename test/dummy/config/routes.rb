Rails.application.routes.draw do

  mount ConcertoSimpleRss::Engine => "/concerto_simple_rss"
end
