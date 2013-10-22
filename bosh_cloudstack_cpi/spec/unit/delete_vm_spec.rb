# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::CloudStackCloud::Cloud do

  before(:each) do
     @registry = mock_registry
   end

  it "deletes an CloudStack server" do
    server = double("server", :id => "i-foobar", :name => "i-foobar")

    cloud = mock_cloud do |cloudstack|
      cloudstack.servers.should_receive(:get).with("i-foobar").and_return(server)
    end

    server.should_receive(:state).and_return(:active)
    server.should_receive(:destroy)
    cloud.should_receive(:wait_resource).with(server, :active, :destroyed, :state)

    @registry.should_receive(:delete_settings).with("i-foobar")

    cloud.delete_vm("i-foobar")
  end
end
