# encoding: utf-8
$:.push File.expand_path("../lib", __FILE__)

require 'plog/version'

Gem::Specification.new do |s|
  s.name         = "plog"
  s.version      = Plog::VERSION
  s.platform     = Gem::Platform::RUBY
  s.authors      = ["Nelson Gauthier"]
  s.email        = ["nelson@airbnb.com"]
  s.homepage     = "https://github.com/airbnb/plog-ruby"
  s.summary      = "Ruby client for Plog."
  s.description  = "Send messages via UDP to the Plog Kafka forwarder."

  s.files        = `git ls-files`.split("\n")
  s.test_files   = `git ls-files -- spec/*`.split("\n")
  s.require_path = 'lib'
end
