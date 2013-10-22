# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::CloudStackCloud::Cloud do

  it "creates an CloudStack volume" do
    unique_name = UUIDTools::UUID.random_create.to_s
    disk_params = {
      :name => "volume-#{unique_name}",
      :size => 2,
      :zone_id => "z-foobar",
      :disk_offering_id => "d-foobar"
    }
    volume = double("volume", :id => "v-foobar", :state => "creating")
    zone = double("zone", :id => "z-foobar")
    disk_offering = double("disk_offering", :id => "d-foobar", :name => "Custom")

    cloud = mock_cloud do |cloudstack|
      cloudstack.zones.should_receive(:find).and_return(zone)
      cloudstack.disk_offerings.should_receive(:find).and_return(disk_offering)
      cloudstack.volumes.should_receive(:create).with(disk_params).and_return(volume)
      cloudstack.volumes.should_receive(:find).and_return(volume)
    end

    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    cloud.should_receive(:wait_resource).with(volume, "creating", :allocated)

    cloud.create_disk(2048).should == "v-foobar"
  end

  it "rounds up disk size" do
    unique_name = UUIDTools::UUID.random_create.to_s
    disk_params = {
      :name => "volume-#{unique_name}",
      :size => 3,
      :zone_id => "z-foobar",
      :disk_offering_id => "d-foobar"
    }
    volume = double("volume", :id => "v-foobar", :state => "creating")
    zone = double("zone", :id => "z-foobar")
    disk_offering = double("disk_offering", :id => "d-foobar", :name => "Custom")

    cloud = mock_cloud do |cloudstack|
      cloudstack.zones.should_receive(:find).and_return(zone)
      cloudstack.disk_offerings.should_receive(:find).and_return(disk_offering)
      cloudstack.volumes.should_receive(:create).with(disk_params).and_return(volume)
      cloudstack.volumes.should_receive(:find).and_return(volume)
    end

    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    cloud.should_receive(:wait_resource).with(volume, "creating", :allocated)

    cloud.create_disk(2049)
  end

  it "check min and max disk size" do
    expect {
      mock_cloud.create_disk(100)
    }.to raise_error(Bosh::Clouds::CloudError, /minimum disk size is 1 GiB/)

    expect {
      mock_cloud.create_disk(2000 * 1024)
    }.to raise_error(Bosh::Clouds::CloudError, /maximum disk size is 1 TiB/)
  end

  it "puts disk in the same zone as a server" do
    unique_name = UUIDTools::UUID.random_create.to_s
    disk_params = {
      :name => "volume-#{unique_name}",
      :size => 1,
      :zone_id => "z-foobar",
      :disk_offering_id => "d-foobar"
    }
    server = double("server", :id => "i-test", :zone_id => "z-foobar")
    volume = double("volume", :id => "v-foobar", :state => "creating")
    zone = double("zone", :id => "z-foobar")
    disk_offering = double("disk_offering", :id => "d-foobar", :name => "Custom")

    cloud = mock_cloud do |cloudstack|
      cloudstack.servers.should_receive(:get).with("i-test").and_return(server)
      cloudstack.disk_offerings.should_receive(:find).and_return(disk_offering)
      cloudstack.volumes.should_receive(:create).with(disk_params).and_return(volume)
      cloudstack.volumes.should_receive(:find).and_return(volume)
    end

    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    cloud.should_receive(:wait_resource).with(volume, "creating", :allocated)

    cloud.create_disk(1024, "i-test")
  end

end
