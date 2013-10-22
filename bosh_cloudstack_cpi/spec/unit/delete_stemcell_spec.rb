# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::CloudStackCloud::Cloud do

  before(:each) do
    @registry = mock_registry
  end

  it "deregisters CloudStack image" do
    image = double("image", :id => "i-foo", :name => "i-foo")

    cloud = mock_cloud do |cloudstack|
      cloudstack.images.stub(:get).with("i-foo").and_return(image)
    end

    image.should_receive(:destroy)

    cloud.delete_stemcell("i-foo")
  end

end
