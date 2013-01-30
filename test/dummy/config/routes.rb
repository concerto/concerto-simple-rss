Rails.application.routes.draw do

  mount C2SimpleRss::Engine => "/c2_simple_rss"
end
