module Plog
  module Packets

    module MultipartMessage
      def self.encode(message_id, length, checksum, chunk_size, count, index, payload)
        return [
          PROTOCOL_VERSION,
          TYPE_MULTIPART_MESSAGE,
          count,
          index,
          chunk_size,
          message_id,
          length,
          checksum,
          payload
        ].pack('CCS>S>S>L>l>L>x4a*')
      end
    end

  end
end
