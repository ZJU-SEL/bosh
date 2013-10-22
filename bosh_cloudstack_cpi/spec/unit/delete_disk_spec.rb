# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::CloudStackCloud::Cloud do

  it "deletes an CloudStack volume" do
    volume = double("volume", :id => "v-foobar", :server_id => nil)

    cloud = mock_cloud do |cloudstack|
      cloudstack.volumes.should_receive(:get).with("v-foobar").and_return(volume)
    end

    volume.should_receive(:state).and_return(:available)
    volume.should_receive(:destroy).and_return(true)

    cloud.delete_disk("v-foobar")
  end

  it "doesn't delete an CloudStack volume unless it's detached from server" do
    volume = double("volume", :id => "v-foobar", :server_id => "i-test")

    cloud = mock_cloud do |cloudstack|
      cloudstack.volumes.should_receive(:get).with("v-foobar").and_return(volume)
    end

    volume.should_receive(:state).and_return(:busy)

    expect {
      cloud.delete_disk("v-foobar")
    }.to raise_error(Bosh::Clouds::CloudError, "Cannot delete volume `v-foobar' because it has been attached to VM `i-test'")
  end

end
