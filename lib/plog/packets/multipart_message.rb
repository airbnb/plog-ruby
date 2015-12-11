module Plog
  module Packets

    module MultipartMessage
      def self.encode(message_id, length, checksum, chunk_size, count, index, payload, options = {})
        message = [
            PROTOCOL_VERSION,
            TYPE_MULTIPART_MESSAGE,
            count,
            index,
            chunk_size,
            message_id,
            length,
            checksum]

        # Plog encoding: https://github.com/airbnb/plog
        template = 'CCS>S>S>L>l>L>S>x2'

        # Generate pack template for tags
        tags = options[:tags]
        if tags.nil? || tags.empty?
          message << 0
        else
          tag_len = 0
          tags.each do |tag|
            len = tag.length + 1 # extra byte for '\0'
            template += "a#{len}"
            tag_len += len
          end
          message << tag_len
          message.concat(tags)
        end

        message << payload
        template += 'a*'

        return message.pack(template)
      end
    end

  end
end
