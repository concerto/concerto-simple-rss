module ConcertoSimpleRss
  class Engine < ::Rails::Engine
    isolate_namespace ConcertoSimpleRss

    initializer "register content type" do |app|
      app.config.content_types << SimpleRss
    end
  end
end
