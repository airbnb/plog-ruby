require 'spec_helper'

describe Plog::Client do

  let(:chunk_size) { 5 }
  let(:client_options) { { :chunk_size => chunk_size } }
  subject { Plog::Client.new(client_options) }

  let(:udp_socket) do
    double(UDPSocket).tap do |udp_socket|
      udp_socket.stub(:send)
      udp_socket.stub(:close)
      udp_socket.stub(:recv)
    end
  end

  before do
    UDPSocket.stub(:new).and_return(udp_socket)
  end

  describe '#stats' do
    let(:select_value) { [[udp_socket], [], []] }
    let(:recv_value) { '{"foo":1}' }

    before do
      IO.stub(:select).and_return(select_value)
      udp_socket.stub(:recv) { recv_value }
    end

    context 'timing out' do
      let(:select_value) { nil }
      it 'raises a TimeoutException' do
        expect {subject.stats}.to raise_error Plog::TimeoutException
      end
    end

    it 'sends a stats request' do
      udp_socket.should_receive(:send) do |req, *extraneous|
        expect(req.downcase).to start_with("\0\0stat")
      end

      subject.stats
    end

    it 'returns a statistics object from deserializing JSON' do
      expect(subject.stats).to eq({'foo' => 1})
    end
  end

  describe '#send' do
    let(:message)  { 'xxx' }
    let(:checksum) { 200 }

    before do
      Plog::Checksum.stub(:compute).and_return(checksum)
    end

    it "constructs a UDP socket" do
      UDPSocket.should_receive(:new).and_return(udp_socket)
      subject.send(message)
    end

    context "when a send buffer size is specified" do
      before do
        client_options.merge!(:send_buffer_size => 1000)
      end

      it "sets the SO_SNDBUF socket option" do
        udp_socket.should_receive(:setsockopt).with(
          Socket::SOL_SOCKET,
          Socket::SO_SNDBUF,
          1000)
        subject.send(message)
      end
    end

    it "contacts the given host and port" do
      udp_socket.should_receive(:send).with(anything(), 0, subject.host, subject.port)
      subject.send(message)
    end

    it "encodes the message id, message length and chunk size" do
      first_id = subject.last_message_id
      Plog::Packets::MultipartMessage.should_receive(:encode).with(
        first_id + 1,
        message.length,
        checksum,
        chunk_size,
        anything(),
        anything(),
        message,
        {}
      ).and_call_original
      subject.send(message)
    end

    it "returns an monotonically increasing message id" do
      first_id = subject.last_message_id
      expect(subject.send(message)).to eq(first_id + 1)
      expect(subject.send(message)).to eq(first_id + 2)
    end

    it "reuses the same socket" do
      UDPSocket.should_receive(:new).once.and_return(udp_socket)
      2.times { subject.send(message) }
    end

    describe 'large messages' do
      let(:large_message_threshold) { nil }
      let(:callback) { lambda { |c, m| } }

      before do
        client_options.merge!({
          :large_message_threshold => large_message_threshold,
          :on_large_message => callback
        })
      end

      context "when the large message threshold is nil" do
        let(:large_message_threshold) { nil }

        it "does not invoke the callback" do
          callback.should_not_receive(:call)
          subject.send(message)
        end
      end

      context "when the large message threshold is given" do
        let(:large_message_threshold) { 2 }
        let(:message)  { 'xxx' }

        it "invokes the callback with the client and message" do
          callback.should_receive(:call).with(subject, message)
          subject.send(message)
        end

        context "when the callback is nil" do
          let(:callback) { nil }

          it "doesn't raise" do
            subject.send(message)
          end
        end
      end
    end

    describe 'message id' do
      before do
        @message_ids = []
        Plog::Packets::MultipartMessage.stub(:encode) do |message_id, _, _, _, _, _, _|
          @message_ids << message_id
        end
      end

      it "encodes each message with a monotonically increasing message id" do
        first_id = subject.last_message_id
        expected_sequence = (first_id + 1...first_id + 6).to_a
        5.times { subject.send(message) }
        expect(@message_ids).to eq(expected_sequence)
      end
    end

    describe 'chunking' do
      let(:chunk_size) { 5 }
      let(:message) { 'AAAA' }
      let(:expected_chunks) { ['AAAA'] }

      before do
        @sent_datagrams = []
        Plog::Packets::MultipartMessage.stub(:encode) do |_, _, _, _, count, index, data|
          [count, index, data]
        end
        udp_socket.stub(:send) do |datagram, _, _, _|
          @sent_datagrams << datagram
        end
      end

      def validate_datagrams
        # Reassemble the message as binary and verify the counts and indexes.
        reassembled_message = "".force_encoding('BINARY')
        @sent_datagrams.each_with_index do |(count, index, data), datagram_index|
          expect(count.to_i).to eq(expected_chunks.count)
          expect(index.to_i).to eq(datagram_index)
          expect(data).to eq(expected_chunks[datagram_index].force_encoding('BINARY'))
          reassembled_message += data
        end
        # Convert the message back to the original encoding and verify.
        reassembled_message.force_encoding(message.encoding)
        expect(reassembled_message).to eq(message)
      end

      context "when the message length is lower than the chunk size" do
        let(:chunk_size) { 5 }
        let(:message) { "A" * (chunk_size - 1) }
        let(:expected_chunks)  { [message] }

        it "encodes the message and sends it as a single packet" do
          subject.send(message)
          validate_datagrams
        end
      end

      context "when the message is large than the chunk size" do
        let(:chunk_size) { 5 }
        let(:message) { "A" * (chunk_size + 1) }
        let(:expected_chunks)  { ["A" * chunk_size, "A"] }

        it "chunks the message and sends it as many packets" do
          subject.send(message)
          validate_datagrams
        end
      end

      context "when the message contains multi-byte encoded characters" do
        let(:chunk_size) { 5 }
        let(:message) { "\u00E9ABCDEFGH" }
        let(:expected_chunks) { [
            "\u00E9ABC",
            "DEFGH"
          ]}

        it "correctly chunks the message" do
          subject.send(message)
          validate_datagrams
        end
      end
    end

    describe 'exceptions' do

      context "when the socket operation raises" do
        it "closes and re-opens the socket" do
          udp_socket.stub(:send).and_raise
          udp_socket.should_receive(:close).once
          expect { subject.send(message) }.to raise_error

          udp_socket.stub(:send) {}
          UDPSocket.should_receive(:new).once.and_return(udp_socket)
          subject.send(message)
        end
      end

    end

  end

  describe '#reset' do
    let(:message)  { 'xxx' }

    it "chooses a new random message id" do
      Random.stub(:rand).and_return(2)
      subject.send(message)
      expect(subject.last_message_id).to eq(3)

      Random.stub(:rand).and_return(5)
      subject.reset
      expect(subject.last_message_id).to eq(5)
    end

    context "with an initialized socket" do
      before do
        subject.send(message)
        subject.socket.should_receive(:close)
        subject.reset
      end

    end

  end

end
