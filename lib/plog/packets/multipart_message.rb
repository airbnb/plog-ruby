module Plog
  module Packets

    module MultipartMessage
      def self.encode(message_id, length, chunk_size, count, index, payload)
        return [
          PROTOCOL_VERSION,
          TYPE_MULTIPART_MESSAGE,
          count,
          index,
          chunk_size,
          message_id,
          length,
          payload
        ].pack('CCS>S>S>l>l>x8a*')
      end
    end

  end
end
