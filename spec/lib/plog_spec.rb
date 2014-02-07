require 'spec_helper'

describe Plog do

  describe '.new' do
    let(:options) { { :foo => :bar } }

    it "returns a plog client" do
      expect(Plog.new).to be_an_instance_of(Plog::Client)
    end

    it "passes options to the client initializer" do
      Plog::Client.should_receive(:new).with(options).and_call_original
      Plog.new(options)
    end
  end

end
