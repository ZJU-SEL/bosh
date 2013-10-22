# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::CloudStackCloud::Cloud do

  before(:each) do
    @registry = mock_registry
  end

  it "detaches an CloudStack volume from a server" do
    server = double("server", :id => "i-test", :name => "i-test",)
    volume = double("volume", :id => "v-foobar", :type => "DATADISK", :server_id => "i-test")
    detach_job = double("job")

    cloud = mock_cloud do |cloudstack|
      cloudstack.servers.should_receive(:get).with("i-test").and_return(server)
      cloudstack.volumes.should_receive(:get).with("v-foobar").and_return(volume)
    end

    volume.should_receive(:state).and_return(:"in-use")
    volume.should_receive(:detach).and_return(detach_job)
    detach_job.should_receive(:wait_for).and_return(cost_time_spec)

    old_settings = {
      "foo" => "bar",
      "disks" => {
        "persistent" => {
          "v-foobar" => "Attached",
          "v-barfoo" => "Attached"
        }
      }
    }

    new_settings = {
      "foo" => "bar",
      "disks" => {
        "persistent" => {
          "v-barfoo" => "Attached"
        }
      }
    }

    @registry.should_receive(:read_settings).with("i-test").and_return(old_settings)
    @registry.should_receive(:update_settings).with("i-test", new_settings)

    cloud.detach_disk("i-test", "v-foobar")
  end

  it "raises an error when volume is not attached to a server" do
    server = double("server", :id => "i-test", :name => "i-test")
    volume = double("volume", :id => "v-barfoo", :type => "DATADISK", :server_id => nil)

    cloud = mock_cloud do |cloudstack|
      cloudstack.servers.should_receive(:get).with("i-test").and_return(server)
      cloudstack.volumes.should_receive(:get).with("v-barfoo").and_return(volume)
    end

    expect {
      cloud.detach_disk("i-test", "v-barfoo")
    }.to raise_error(Bosh::Clouds::CloudError, /is not attached to server/)
  end

end
