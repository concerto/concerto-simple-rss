module C2SimpleRss
  class Engine < ::Rails::Engine
    isolate_namespace C2SimpleRss

    initializer "register content type" do |app|
      app.config.content_types << SimpleRss
    end
  end
end
