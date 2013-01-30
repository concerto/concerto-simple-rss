Rails.application.routes.draw do
  resources :simple_rsses, :controller => :contents, :except => [:index, :show], :path => "content"
end
