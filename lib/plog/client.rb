require 'socket'
require 'thread'
require 'logger'

module Plog
  class Client
    # The protocol version spoken by this client.
    PROTOCOL_VERSION = Packets::PROTOCOL_VERSION

    DEFAULT_OPTIONS = {
      :host => 'localhost',
      :port => 23456,
      :chunk_size => 64000,
      :logger => Logger.new(nil)
    }

    attr_reader :host
    attr_reader :port
    attr_reader :chunk_size
    attr_reader :logger

    def initialize(options={})
      options = DEFAULT_OPTIONS.merge(options)
      @host = options[:host]
      @port = options[:port]
      @chunk_size = options[:chunk_size]
      @logger = options[:logger]

      @last_message_id = -1
      @message_id_mutex = Mutex.new
    end

    def send(message)
      message_id = next_message_id
      message_length = message.length
      chunks = chunk_string(message, chunk_size)

      logger.debug { "Plog: sending (#{message_id}; #{chunks.length} chunk(s))" }
      chunks.each_with_index do |data, index|
        send_to_socket(
          Packets::MultipartMessage.encode(
            message_id,
            message_length,
            chunk_size,
            chunks.count,
            index,
            data
          ))
      end

      message_id
    rescue => e
      logger.error { "Plog: error sending message: #{e}" }
      raise e
    end

    private

    def next_message_id
      @message_id_mutex.synchronize do
        @last_message_id += 1
        @last_message_id %= 2 ** 32
      end
    end

    def chunk_string(string, size)
      (0..(string.length - 1) / size).map { |i| string[i * size, size] }
    end

    def send_to_socket(string)
      logger.debug { "Plog: writing to socket: #{string.inspect}" }
      socket.send(string, 0, host, port)
    rescue => e
      logger.error { "Plog: error writing to socket: #{e}" }
      close_socket
      raise e
    end

    def socket
      @socket ||= UDPSocket.new
    end

    def close_socket
      @socket.close rescue nil
      @socket = nil
    end
  end
end
