module Plog
  module Packets

    module MultipartMessage
      def self.encode(message_id, length, chunk_size, count, index, payload)
        return [
          PROTOCOL_VERSION,
          TYPE_MULTIPART_MESSAGE,
          # As there is always at least one packet, count begins at zero for
          # a single-part message.
          count - 1,
          index,
          chunk_size,
          message_id,
          length,
          payload
        ].pack('CCS>S>S>L>l>x8a*')
      end
    end

  end
end
