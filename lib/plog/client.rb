require 'json'
require 'socket'
require 'thread'
require 'logger'

module Plog
  class TimeoutException < StandardError
  end

  class Client
    # The protocol version spoken by this client.
    PROTOCOL_VERSION = Packets::PROTOCOL_VERSION
    RECV_SIZE = 65_536

    DEFAULT_OPTIONS = {
      :host => '127.0.0.1',
      :port => 23456,
      # Use the socket's default value unless this option is specified.
      :send_buffer_size => nil,
      :chunk_size => 64000,

      :large_message_threshold => nil,
      :on_large_message => nil,
      :logger => Logger.new(nil)
    }

    attr_reader :host
    attr_reader :port
    attr_reader :send_buffer_size
    attr_reader :chunk_size

    attr_reader :large_message_threshold
    attr_reader :on_large_message
    attr_reader :logger

    attr_reader :last_message_id

    def initialize(options={})
      options = DEFAULT_OPTIONS.merge(options)
      @host = options[:host]
      @port = options[:port]
      @send_buffer_size = options[:send_buffer_size]
      @chunk_size = options[:chunk_size]
      @large_message_threshold = options[:large_message_threshold]
      @on_large_message = options[:on_large_message]
      @logger = options[:logger]

      @message_id_mutex = Mutex.new
      reset_message_id
    end

    def stats(timeout = 3.0)
      send_to_socket("\0\0stats")
      JSON.parse receive_packet_from_socket(timeout)
    end

    def send(message, options = {})
      # Interpret the encoding of the string as binary so that chunking occurs
      # at the byte-level and not at the character-level.
      message = message.dup.force_encoding('BINARY')
      notify_large_message(message) if large_message?(message)

      message_id = next_message_id
      message_length = message.length
      message_checksum = Checksum.compute(message)
      chunks = chunk_string(message, chunk_size)

      logger.debug { "Plog: sending (#{message_id}; #{chunks.length} chunk(s))" }
      chunks.each_with_index do |data, index|
        send_to_socket(
          Packets::MultipartMessage.encode(
            message_id,
            message_length,
            message_checksum,
            chunk_size,
            chunks.count,
            index,
            data,
            options
          ))
      end

      message_id
    rescue => e
      logger.error { "Plog: error sending message: #{e}" }
      raise e
    end

    def reset
      reset_message_id
      close_socket
    end

    def socket
      @socket ||= open_socket
    end

    private

    def large_message?(message)
      large_message_threshold && message.length > large_message_threshold
    end

    def notify_large_message(message)
      on_large_message && on_large_message.call(self, message)
    end

    def reset_message_id
      @message_id_mutex.synchronize do
        @last_message_id = Random.rand(2 ** 32)
      end
    end

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

    def receive_packet_from_socket(timeout)
      logger.debug { "Plog: receiving from socket #{socket} with timeout #{timeout}s" }

      if IO::select([socket], nil, nil, timeout).nil?
        raise TimeoutException, "No answer in #{timeout}s"
      end

      socket.recv RECV_SIZE
    end

    def open_socket
      socket = UDPSocket.new
      if send_buffer_size
        socket.setsockopt(
          Socket::SOL_SOCKET,
          Socket::SO_SNDBUF,
          send_buffer_size
        )
      end
      socket
    end

    def close_socket
      @socket.close rescue nil
      @socket = nil
    end
  end
end
