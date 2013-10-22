# Copyright (c) 2012 Piston Cloud Computing, Inc.

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)

require "rubygems"
require "bundler"

Bundler.setup(:default, :test)

require "rspec"
require "tmpdir"

require "cloud/cloudstack"

class CloudStackConfig
  attr_accessor :db, :logger, :uuid
end

os_config = CloudStackConfig.new
os_config.db = nil # CloudStack CPI doesn't need DB
os_config.logger = Logger.new(StringIO.new)
os_config.logger.level = Logger::DEBUG

Bosh::Clouds::Config.configure(os_config)

def internal_to(*args, &block)
  example = describe *args, &block
  klass = args[0]
  if klass.is_a? Class
    saved_private_instance_methods = klass.private_instance_methods
    example.before do
      klass.class_eval { public *saved_private_instance_methods }
    end
    example.after do
      klass.class_eval { private *saved_private_instance_methods }
    end
  end
end

def mock_cloud_options
  {
    "cloudstack" => {
      "host" => "172.17.13.188",
      "port" => "8080",
      "scheme" => "http",
      "api_key" => "C1aCo8A5J_fqiTbTv9Tj9MlU-8tTO2aOJeb4XFYciDl9TK9OGAHE71Yb9ZXsp8L9-Lt3OBWiF9chEDEjQEI74Q",
      "secret_access_key" => "worQERQsTaor80zPdJGvxlPoLSrHJiPefftpZut_OYJkaQ6ygCB03aiK1ahqqKTXBNUEQml-rSLU-n-5hnL5ag"
    },
    "registry" => {
      "endpoint" => "localhost:3000",
      "user" => "admin",
      "password" => "admin"
    },
    "agent" => {
      "foo" => "bar",
      "baz" => "zaz"
    }
  }
end

def make_cloud(options = nil)
  Bosh::CloudStackCloud::Cloud.new(options || mock_cloud_options)
end

def mock_registry(endpoint = "http://registry:3333")
  registry = mock("registry", :endpoint => endpoint)
  Bosh::CloudStackCloud::RegistryClient.stub!(:new).and_return(registry)
  registry
end

def mock_cloud(options = nil)
  servers = double("servers")
  images = double("images")
  flavors = double("flavors")
  volumes = double("volumes")
  snapshots = double("snapshots")
  networks = double("networks")
  ipaddresses = double("ipaddresses")
  nats = double("nats")
  vlans = double("vlans")
  zones = double("zones")
  disk_offerings = double("disk_offerings")

  cloudstack = double(Fog::Compute)

  cloudstack.stub(:servers).and_return(servers)
  cloudstack.stub(:images).and_return(images)
  cloudstack.stub(:flavors).and_return(flavors)
  cloudstack.stub(:volumes).and_return(volumes)
  cloudstack.stub(:snapshots).and_return(snapshots)
  cloudstack.stub(:networks).and_return(networks)
  cloudstack.stub(:ipaddresses).and_return(ipaddresses)
  cloudstack.stub(:nats).and_return(nats)
  cloudstack.stub(:vlans).and_return(vlans)
  cloudstack.stub(:zones).and_return(zones)
  cloudstack.stub(:disk_offerings).and_return(disk_offerings)

  Fog::Compute.stub(:new).and_return(cloudstack)

  yield cloudstack if block_given?

  Bosh::CloudStackCloud::Cloud.new(options || mock_cloud_options)
end

def dynamic_network_spec
  { "type" => "dynamic" }
end

def vip_network_spec
  {
    "type" => "vip",
    "ip" => "10.0.0.1"
  }
end

def combined_network_spec
  {
    "network_a" => dynamic_network_spec,
    "network_b" => vip_network_spec
  }
end

def resource_pool_spec
  {
    "key_name" => "test_key",
    "availability_zone" => "foobar-1a",
    "instance_type" => "m1.tiny"
  }
end

def cost_time_spec
  {
    :duration => 1
  }
end
