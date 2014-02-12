require 'plog/version'
require 'plog/packets'
require 'plog/checksum'
require 'plog/client'

module Plog
  def self.new(options={})
    Plog::Client.new(options)
  end
end
