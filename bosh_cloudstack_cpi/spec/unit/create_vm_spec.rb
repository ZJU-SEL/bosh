# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::CloudStackCloud::Cloud, "create_vm" do

  def agent_settings(unique_name, network_spec = dynamic_network_spec)
    {
      "vm" => {
        "name" => "vm-#{unique_name}"
      },
      "agent_id" => "agent-id",
      "networks" => { "network_a" => network_spec },
      "disks" => {
        "system" => "/dev/vda",
        "ephemeral" => "/dev/vdb",
        "persistent" => {}
      },
      "env" => {
        "test_env" => "value"
      },
      "foo" => "bar", # Agent env
      "baz" => "zaz"
    }
  end

  def cloudstack_params(unique_name, user_data, security_groups=[])
    {
      :display_name=>"vm-#{unique_name}",
      :image_id => "sc-id",
      :flavor_id => "f-test",
      :user_data => Base64.encode64(user_data),
      :zone_id => "foobar-1a",
      :network_ids => "foo",
      :key_pair => "test_key"
    }
  end

  before(:each) do
    @registry = mock_registry
  end

  it "creates an CloudStack server and polls until it's ready" do
    unique_name = UUIDTools::UUID.random_create.to_s
    user_data = "http://registry:3333"
    server = double("server", :id => "i-test", :name => "i-test", :state => "creating")
    image = double("image", :id => "sc-id", :name => "sc-id")
    flavor = double("flavor", :id => "f-test", :name => "m1.tiny")
    address = double("address", :id => "a-test", :ip_address => "10.0.0.1", :virtual_machine_id => "i-test")
    zone = double("zone", :id => "foobar-1a", :name => "foobar-1a")
    network  = double("network", :id => "foo", :name => "foo")
    static_nat = double("static_nat")
    static_nat_job = double("job")

    cloud = mock_cloud do |cloudstack|
      cloudstack.servers.should_receive(:create).with(cloudstack_params(unique_name, user_data)).and_return(server)
      cloudstack.images.should_receive(:find).and_return(image)
      cloudstack.flavors.should_receive(:find).and_return(flavor)
      cloudstack.zones.should_receive(:find).and_return(zone)
      cloudstack.ipaddresses.should_receive(:each).and_yield(address)
      cloudstack.nats.should_receive(:new).and_return(static_nat)
      cloudstack.servers.should_receive(:find).and_return(server)
      cloudstack.networks.should_receive(:find).and_return(network)
    end

    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    static_nat.should_receive(:disable).and_return(static_nat_job)
    static_nat_job.should_receive(:wait_for).and_return(cost_time_spec)
    cloud.should_receive(:wait_resource).with(server, "creating", :running, :state)

    @registry.should_receive(:update_settings).with("i-test", agent_settings(unique_name))

    vm_id = cloud.create_vm("agent-id", "sc-id",
                            resource_pool_spec,
                            { "network_a" => dynamic_network_spec },
                            nil, { "test_env" => "value" })
    vm_id.should == "i-test"
  end

  it "associates server with floating ip if vip network is provided" do
    server = double("server", :id => "i-test", :name => "i-test", :state => "creating")
    image = double("image", :id => "sc-id", :name => "sc-id")
    flavor = double("flavor", :id => "f-test", :name => "m1.tiny")
    address = double("address", :id => "a-test", :ip_address => "10.0.0.1", :virtual_machine_id => "j-test")
    zone = double("zone", :id=>"foobar-1a", :name => "foobar-1a")
    network = double("network", :id => "n-test")
    static_nat = double("static_nat")
    static_nat_job = double("job")
    

    cloud = mock_cloud do |cloudstack|
      cloudstack.servers.should_receive(:create).and_return(server)
      cloudstack.images.should_receive(:find).and_return(image)
      cloudstack.flavors.should_receive(:find).and_return(flavor)
      cloudstack.zones.should_receive(:find).and_return(zone)
      cloudstack.servers.should_receive(:find).and_return(server)
      cloudstack.networks.should_receive(:find).at_least(:once).and_return(network)
      cloudstack.ipaddresses.should_receive(:find).and_return(address)
      cloudstack.nats.should_receive(:new).and_return(static_nat)
    end

    static_nat.should_receive(:disable).and_return(static_nat_job)
    static_nat_job.should_receive(:wait_for).and_return(cost_time_spec)
    static_nat.should_receive(:virtual_machine_id=).with("i-test")
    static_nat.should_receive(:enable)
    cloud.should_receive(:wait_resource).with(server, "creating", :running, :state)

    @registry.should_receive(:update_settings)

    vm_id = cloud.create_vm("agent-id", "sc-id",
                            resource_pool_spec,
                            combined_network_spec)
  end

end
