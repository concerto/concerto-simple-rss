$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "c2_simple_rss/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "c2_simple_rss"
  s.version     = C2SimpleRss::VERSION
  s.authors     = ["Brian Michalski"]
  s.email       = ["bmichalski@gmail.com"]
  s.homepage    = "http://www.concerto-signage.org"
  s.summary     = "RSS Dynamic Concerto for Concerto 2."
  s.description = "Simple support to render RSS content in Concerto 2."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 3.2.11"

  s.add_development_dependency "sqlite3"
end
