require 'murmurhash3'

module Plog
  module Checksum
    def self.compute(string)
      MurmurHash3::V32.str_hash(string)
    end
  end
end
