# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::CloudStackCloud::Cloud do

  before(:each) do
    @registry = mock_registry
  end

  it "adds floating ip to the server for vip network" do
    server = double("server", :id => "i-test", :name => "i-test", :zone_id => "i-zone")
    address = double("address", :id => "a-test", :ip_address => "10.0.0.1", :virtual_machine_id => nil)
    network = double("network", :id => "n-test")
    static_nat = double("static_nat")
    vlan = double("vlan")
    address_job = double("job")

    cloud = mock_cloud do |cloudstack|
      cloudstack.servers.should_receive(:get).with("i-test").and_return(server)
      cloudstack.ipaddresses.should_receive(:find).and_return(nil)
      cloudstack.ipaddresses.should_receive(:new).and_return(address)
      cloudstack.networks.should_receive(:find).and_return(network)
      cloudstack.vlans.should_receive(:new).and_return(vlan)
      cloudstack.nats.should_receive(:new).and_return(static_nat)
    end

    vlan.should_receive(:create_vlan_ip_range)
    address.should_receive(:associate).and_return(address_job)
    address_job.should_receive(:wait_for)
    static_nat.should_receive(:enable)

    old_settings = { "foo" => "bar", "networks" => "baz" }
    new_settings = { "foo" => "bar", "networks" => combined_network_spec }

    @registry.should_receive(:read_settings).with("i-test").and_return(old_settings)
    @registry.should_receive(:update_settings).with("i-test", new_settings)

    cloud.configure_networks("i-test", combined_network_spec)
  end

=begin
  it "adds floating ip to the server for vip network" do
    server = double("server", :id => "i-test", :name => "i-test")
    address = double("address", :id => "a-test", :ip_address => "10.0.0.1", :virtual_machine_id => nil)
    network = double("network", :id => "n-test", :name => "advance")
    static_nat = double("static_nat")

    cloud = mock_cloud do |cloudstack|
      cloudstack.servers.should_receive(:get).with("i-test").and_return(server)
      cloudstack.ipaddresses.should_receive(:find).and_return(address)
      cloudstack.networks.should_receive(:find).and_return(network)
      cloudstack.nats.should_receive(:new).and_return(static_nat)
    end

    static_nat.should_receive(:enable)

    old_settings = { "foo" => "bar", "networks" => "baz" }
    new_settings = { "foo" => "bar", "networks" => combined_network_spec }

    @registry.should_receive(:read_settings).with("i-test").and_return(old_settings)
    @registry.should_receive(:update_settings).with("i-test", new_settings)

    cloud.configure_networks("i-test", combined_network_spec)
  end
=end


  it "removes floating ip from the server if vip network is gone" do
    server = double("server", :id => "i-test", :name => "i-test")
    address = double("address", :id => "a-test", :ip_address => "10.0.0.1", :virtual_machine_id => "i-test")
    static_nat = double("static_nat")
    static_nat_job = double("job")

    cloud = mock_cloud do |cloudstack|
      cloudstack.servers.should_receive(:get).with("i-test").and_return(server)
      cloudstack.ipaddresses.should_receive(:each).and_yield(address)
      cloudstack.nats.should_receive(:new).and_return(static_nat)
    end

    static_nat.should_receive(:disable).and_return(static_nat_job)
    static_nat_job.should_receive(:wait_for).and_return(cost_time_spec)


    old_settings = { "foo" => "bar", "networks" => combined_network_spec }
    new_settings = { "foo" => "bar", "networks" => { "net_a" => dynamic_network_spec } }

    @registry.should_receive(:read_settings).with("i-test").and_return(old_settings)
    @registry.should_receive(:update_settings).with("i-test", new_settings)

    cloud.configure_networks("i-test", "net_a" => dynamic_network_spec)
  end

  it "performs network sanity check" do
    server = double("server", :id => "i-test", :name => "i-test")

    expect {
      cloud = mock_cloud do |openstack|
        openstack.servers.should_receive(:get).with("i-test").and_return(server)
      end
      cloud.configure_networks("i-test", "net_a" => vip_network_spec)
    }.to raise_error(Bosh::Clouds::CloudError, "At least one dynamic network should be defined")

    expect {
      cloud = mock_cloud do |openstack|
        openstack.servers.should_receive(:get).with("i-test").and_return(server)
      end
      cloud.configure_networks("i-test", "net_a" => vip_network_spec, "net_b" => vip_network_spec)
    }.to raise_error(Bosh::Clouds::CloudError, /More than one vip network/)

    expect {
      cloud = mock_cloud do |openstack|
        openstack.servers.should_receive(:get).with("i-test").and_return(server)
      end
      cloud.configure_networks("i-test", "net_a" => dynamic_network_spec, "net_b" => dynamic_network_spec)
    }.to raise_error(Bosh::Clouds::CloudError, /More than one dynamic network/)

    expect {
      cloud = mock_cloud do |openstack|
        openstack.servers.should_receive(:get).with("i-test").and_return(server)
      end
      cloud.configure_networks("i-test", "net_a" => { "type" => "foo" })
    }.to raise_error(Bosh::Clouds::CloudError, /Invalid network type `foo'/)
  end

end