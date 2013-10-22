# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::CloudStackCloud::Cloud do

  before :each do
    @tmp_dir = Dir.mktmpdir
  end

  describe "Image upload based flow" do

    it "creates stemcell by uploading an image" do
      image = double("image", :id => "i-bar", :name => "i-bar")
      cloud_properties = double("cloud_properties", :name => "i-bar", :version => "1")
      unique_name = UUIDTools::UUID.random_create.to_s
      image_params = {
          :name => "BOSH-#{unique_name}",
          :disk_format => "ami",
          :container_format => "ami",
          :location => "#{@tmp_dir}/root.img",
          :is_public => true
      }
      zone = double("zone", :id => "z-foobar")
      ostypes = double("ostypes", :all => ["1","2","3"])
      cloud = mock_cloud do |cloudstack|
        cloudstack.zones.should_receive(:find).and_return(zone)
        cloudstack.should_receive(:ostypes).and_return(ostypes)
        cloudstack.images.should_receive(:new).and_return(image)
      end

      Dir.should_receive(:mktmpdir).and_yield(@tmp_dir)
      cloud.should_receive(:unpack_image).with(@tmp_dir, "/tmp/foo")
      #cloud.should_receive(:generate_unique_name).and_return(unique_name)
      cloud.should_receive(:'`').with("cp -a #{@tmp_dir} /")
      cloud.should_receive(:'`').with("chmod o+rx /#{File.basename(@tmp_dir)}")

      Dir.should_receive(:chdir)
      FileUtils.should_receive(:copy).with("default","default.bak")
      cloud.should_receive(:'`').with("grep -n '^[[:blank:]]*server[[:blank:]]*\{' default | sed 's/\\([[:digit:]]\\{1,2\\}\\):server[[:blank:]]*\{/\\1/g' | xargs -icc sed  'cca location /#{File.basename(@tmp_dir)} \{ \\nroot \/\;\\nautoindex on\;\\nallow 0.0.0.0\/0\;\\ndeny all\;\\n\}' default >default.new")
      FileUtils.should_receive(:copy).with("default.new","default")
      cloud.should_receive(:'`').with("/etc/init.d/nginx stop").at_least(:once)
      cloud.should_receive(:'`').with("/etc/init.d/nginx start").at_least(:once)
      cloud.should_receive(:'`').with("ifconfig | grep -A 1 'eth0' | grep 'inet' | sed 's/^.*inet[[:blank:]]*addr:\\([0-9\.]*\\).*/\\1/g'").and_return("172.17.13.84")
      ipaddress = double("ipaddress")
      image.should_receive(:register)
      image.should_receive(:status).and_return(:uploading)
      cloud.should_receive(:wait_resource).with(image, :uploading, :"download complete", :status)
      cloud.should_receive(:'`').at_least(:once)
      FileUtils.should_receive(:copy).with("default.bak", "default")
      sc_id = cloud.create_stemcell("/tmp/foo",
                                    {"name" => "i-bar",
                                     "version" => "1",
                                     "disk_format" => "qcow2"})
      sc_id.should == "i-bar"
    end

  end

end
