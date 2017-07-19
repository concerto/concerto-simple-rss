module ConcertoSimpleRss
  class Engine < ::Rails::Engine
    require 'encryptor'

    isolate_namespace ConcertoSimpleRss

    initializer "register content type" do |app|
      app.config.content_types << SimpleRss

      Encryptor.default_options.merge!(key: ENV["SECRET_KEY_BASE"])
      Encryptor.default_options.merge!(iv: ENV["SECRET_KEY_BASE"])
    end
  end
end
