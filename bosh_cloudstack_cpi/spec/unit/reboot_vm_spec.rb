# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::CloudStackCloud::Cloud do

  it "reboots an CloudStack server" do
    server = double("server", :id => "i-foobar")
    reboot_job = double("job")
    cloud = mock_cloud do |cloudstack|
      cloudstack.servers.stub(:get).with("i-foobar").and_return(server)
    end
    
    server.should_receive(:state).and_return(:reboot)
    server.should_receive(:reboot).and_return(reboot_job)
    reboot_job.should_receive(:wait_for).and_return(cost_time_spec)
    cloud.reboot_vm("i-foobar")
  end

end
