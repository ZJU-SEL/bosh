# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::CloudStackCloud::Cloud do

  before(:each) do
    @registry = mock_registry
  end

  it "attaches an CloudStack volume to a server" do
    server = double("server", :id => "i-test", :name => "i-test")
    volume = double("volume", :id => "v-foobar")
    attach_job = double("job")

    cloud = mock_cloud do |cloudstack|
      cloudstack.servers.should_receive(:get).with("i-test").and_return(server)
      cloudstack.volumes.should_receive(:get).with("v-foobar").and_return(volume)
    end

    volume.should_receive(:attach).with(server).and_return(attach_job)
    attach_job.should_receive(:wait_for).and_return(cost_time_spec)

    old_settings = { "foo" => "bar" }
    new_settings = {
      "foo" => "bar",
      "disks" => {
        "persistent" => {
          "v-foobar" => "Attached"
        }
      }
    }

    @registry.should_receive(:read_settings).with("i-test").and_return(old_settings)
    @registry.should_receive(:update_settings).with("i-test", new_settings)

    cloud.attach_disk("i-test", "v-foobar")
  end

 end
