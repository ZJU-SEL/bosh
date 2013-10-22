# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::CloudStackCloud::NetworkConfigurator do
  
  def foo_network_spec
  {
    "type" => "foo",
    "ip" => "10.0.0.1"
  }
  end

  it "should raise an error if the spec isn't a hash" do
    lambda {
      Bosh::CloudStackCloud::NetworkConfigurator.new("foo")
    }.should raise_error ArgumentError
  end
  
  it "should raise an error if there are more than one dynamic network" do
    spec = {}
    spec["network_a"] = dynamic_network_spec
    spec["network_b"] = dynamic_network_spec
    spec["network_c"] = vip_network_spec
    lambda {
      Bosh::CloudStackCloud::NetworkConfigurator.new(spec)
    }.should raise_error Bosh::Clouds::CloudError, /More than one dynamic network/
  end
  
  it "should raise an error if there is no dynamic network" do
    spec = {}
    spec["network_a"] = vip_network_spec
    lambda {
      Bosh::CloudStackCloud::NetworkConfigurator.new(spec)
    }.should raise_error Bosh::Clouds::CloudError, /At least one dynamic network/
  end
  
  it "should raise an error if there are more than one vip network" do
    spec = {}
    spec["network_a"] = dynamic_network_spec
    spec["network_b"] = vip_network_spec
    spec["network_c"] = vip_network_spec
    lambda {
      Bosh::CloudStackCloud::NetworkConfigurator.new(spec)
    }.should raise_error Bosh::Clouds::CloudError, /More than one vip network/
  end
  
  it "should raise an error if there is invalid network type" do
    spec = {}
    spec["network_a"] = dynamic_network_spec
    spec["network_b"] = foo_network_spec
    lambda {
      Bosh::CloudStackCloud::NetworkConfigurator.new(spec)
    }.should raise_error Bosh::Clouds::CloudError, /Invalid network type/
  end

end