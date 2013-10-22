# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

require "tempfile"

describe Bosh::CloudStackCloud::Cloud do

  before(:each) do
    unless ENV["CPI_CONFIG_FILE"]
      raise "Please provide CPI_CONFIG_FILE environment variable"
    end
    @config = YAML.load_file(ENV["CPI_CONFIG_FILE"])
    @logger = Logger.new(STDOUT)
    @image_id
  end

  let(:cpi) do
    cpi = Bosh::CloudStackCloud::Cloud.new(@config)
    cpi.logger = @logger

    # As we inject the configuration file from the outside, we don't care
    # about spinning up the registry ourselves. However we don't want to bother
    # EC2 at all if registry is not working, so just in case we perform a test
    # health check against whatever has been provided.
    cpi.registry.update_settings("foo", { "bar" => "baz" })
    cpi.registry.read_settings("foo").should == { "bar" => "baz"}

    cpi
  end
  
  it "creates a template" do
    image_id=cpi.create_stemcell("/tmp/tmltar/stemcell.tar.gz",
    { :name => "vliscpitesttemplate", :version => "0.0.1",
      :format => "QCOW2", :hypervisor => "KVM", :os_type_id => "188a147c-a132-4c8e-9067-dfa5a9e4b5cf",
      :is_featured => "true", :zone_id => "745c3088-4d8d-4198-8b1b-053658596cb9"
      })
    image_id.should_not be_nil
    @image_id=image_id  
  end
  it "deletes a template" do
    image_id=@image_id
    result=cpi.delete_stemcell(image_id)
    result.should == true
  end

  it "exercises a VM lifecycle" do
    instance_id = cpi.create_vm(
      "agent-007", "c6ba101a-ee89-4b00-8786-a8c258aa9d56",
      { "instance_type" => "cpitest", "availability_zone" => "zjuvlis_zone" , "network_name" => "network1"},
      { "default" => { "type" => "dynamic" }},
      [], { "key" => "value" })

    instance_id.should_not be_nil
    
    
    settings = cpi.registry.read_settings(instance_id)
    settings["vm"].should be_a(Hash)
    settings["vm"]["name"].should_not be_nil
    settings["agent_id"].should == "agent-007"
    settings["networks"].should == { "default" => { "type" => "dynamic" }}
    settings["disks"].should == {
        "system" => "/dev/vda",
        "ephemeral" => "/dev/vdb",
        "persistent" => {}
    }

    settings["env"].should == { "key" => "value" }

    volume_id = cpi.create_disk(2048)
    volume_id.should_not be_nil

    cpi.attach_disk(instance_id, volume_id)
    settings = cpi.registry.read_settings(instance_id)
    settings["disks"]["persistent"].should == { volume_id => "Attached" }

    cpi.detach_disk(instance_id, volume_id)
    settings = cpi.registry.read_settings(instance_id)
    settings["disks"]["persistent"].should == {}

    dynamic_network_spec = { "type" => "dynamic" }

    vip_network_spec = {
        "type" => "vip",
        "ip" => "172.17.13.232"
    }

    network_spec = {
        "network1" => vip_network_spec,
        "network2" => dynamic_network_spec
    }

    cpi.configure_networks(instance_id, network_spec)

    settings = cpi.registry.read_settings(instance_id)
    settings["networks"].should == network_spec
    cpi.delete_vm(instance_id)
    cpi.delete_disk(volume_id)

    # Test below would fail: CloudStack still reports the instance as 'destroyed'
    # for some time.
    # cpi.cloudstack.servers.get(instance_id).should be_nil

    expect {
      cpi.registry.read_settings(instance_id)
    }.to raise_error(/HTTP 404/)
  end
end
