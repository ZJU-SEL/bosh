# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)
require "tempfile"

describe Bosh::CloudStackCloud::Cloud do

  it "validate cloudstack registry" do
    unless ENV["CPI_CONFIG_FILE"]
      raise "Please provide CPI_CONFIG_FILE environment variable"
    end
    @config = YAML.load_file(ENV["CPI_CONFIG_FILE"])
    @logger = Logger.new(STDOUT)

    cpi = Bosh::CloudStackCloud::Cloud.new(@config)
    cpi.logger = @logger

    cpi.registry.update_settings("foo", { "bar" => "baz" })
    cpi.registry.read_settings("foo").should == { "bar" => "baz"}
    cpi.registry.delete_settings("foo")

  end

end