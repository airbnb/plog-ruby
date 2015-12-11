require 'spec_helper'

describe Plog::Packets::MultipartMessage do

  describe '.encode' do

    # Each of these values were chosen to fit in a single byte.
    let(:message_id) { 1 }
    let(:length)     { 2 }
    let(:checksum)   { 3 }
    let(:chunk_size) { 4 }
    let(:count)      { 5 }
    let(:index)      { 6 }
    let(:payload)    { 'xxx' }

    let(:encoded) do
      Plog::Packets::MultipartMessage.encode(
        message_id,
        length,
        checksum,
        chunk_size,
        count,
        index,
        payload
      )
    end

    def encoded_range(first, last)
      encoded[first..last].bytes.to_a
    end

    it "encodes a string with length 24 + payload length" do
      expect(encoded.length).to eq(24 + payload.length)
    end

    it "encodes the protocol version as the first byte" do
      expect(encoded_range(0, 0)).to eq([Plog::Client::PROTOCOL_VERSION])
    end

    it "encodes the command as the second byte" do
      expect(encoded_range(1, 1)).to eq([Plog::Packets::TYPE_MULTIPART_MESSAGE])
    end

    it "encodes the multipart packet count big endian as bytes 02-03" do
      expect(encoded_range(2, 3)).to eq([0, count])
    end

    it "encodes the multipart packet index big endian as bytes 04-05" do
      expect(encoded_range(4, 5)).to eq([0, index])
    end

    it "encodes the chunk size big endian as bytes 06-07" do
      expect(encoded_range(6, 7)).to eq([0, chunk_size])
    end

    it "encodes the message id big endian as bytes 08-11" do
      expect(encoded_range(8, 11)).to eq([0, 0, 0, message_id])
    end

    it "encodes the total message length as bytes 12-15" do
      expect(encoded_range(12, 15)).to eq([0, 0, 0, length])
    end

    it "encodes the message checksum as bytes 16-19" do
      expect(encoded_range(16, 19)).to eq([0, 0, 0, checksum])
    end

    it "encodes zero padding for the reserved segment as bytes 20-23" do
      expect(encoded_range(20, 23)).to eq([0, 0, 0, 0])
    end

    let(:tags)       { ['tag1', 'tag2'] }
    let(:encoded_with_tags) do
      Plog::Packets::MultipartMessage.encode(
        message_id,
        length,
        checksum,
        chunk_size,
        count,
        index,
        payload,
        tags: tags
      )
    end

    def encoded_with_tags_range(first, last)
      encoded_with_tags[first..last].bytes.to_a
    end

    it "encodes the tags length as bytes 20-21" do
      expect(encoded_with_tags_range(20, 21)).to eq([0, 10])
    end

    it "encodes a tagged string with length 24 + tag length + payload length" do
      expect(encoded_with_tags.length).to eq(24 + 10 + payload.length)
    end

  end

end
