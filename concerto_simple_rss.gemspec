$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "concerto_simple_rss/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "concerto_simple_rss"
  s.version     = ConcertoSimpleRss::VERSION
  s.authors     = ["Brian Michalski"]
  s.email       = ["bmichalski@gmail.com"]
  s.homepage    = "https://github.com/concerto/concerto-simple-rss/"
  s.summary     = "RSS Dynamic Concerto for Concerto 2."
  s.description = "Simple support to render RSS content in Concerto 2."
  s.license     = 'Apache 2.0'

  s.files = Dir["{app,config,db,lib,public}/**/*"] + ["LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails"
  s.add_dependency "ruby-xslt", "~> 0.9"
=
end
