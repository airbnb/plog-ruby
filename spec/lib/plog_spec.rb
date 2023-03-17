require 'spec_helper'

describe Plog do

  describe '.new' do
    let(:options) { { :foo => :bar } }

    it "returns a plog client" do
      expect(Plog.new).to be_an_instance_of(Plog::Client)
    end

    it "passes options to the client initializer" do
      expect_any_instance_of(Plog::Client).to receive(:initialize).with(options).and_call_original
      Plog.new(options)
    end
  end

end
