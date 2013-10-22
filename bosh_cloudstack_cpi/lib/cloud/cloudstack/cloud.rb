# Copyright (c) 2012 Piston Cloud Computing, Inc.
require 'net/scp'

module Bosh::CloudStackCloud

  class Cloud < Bosh::Cloud
    include Helpers

    DEVICE_POLL_TIMEOUT = 60 # seconds
    METADATA_TIMEOUT = 5 # seconds

    attr_reader :cloudstack
    attr_reader :registry
    attr_accessor :logger

    ##
    # Initialize BOSH CloudStack CPI
    # @param [Hash] options CPI options
    #
    def initialize(options)
      @options = options.dup

      validate_options

      @logger = Bosh::Clouds::Config.logger

      @agent_properties = @options["agent"] || {}
      @cloudstack_properties = @options["cloudstack"]
      @registry_properties = @options["registry"]

      @default_availability_zone = @cloudstack_properties["default_zone"]
      @default_key_name = @cloudstack_properties["default_key_name"]
      @stemcell_server_params = @cloudstack_properties["stemcell_server_params"]

      cloudstack_params = {
          :provider => "Cloudstack",
          :cloudstack_host => @cloudstack_properties["host"],
          :cloudstack_port => @cloudstack_properties["port"],
          :cloudstack_scheme=> @cloudstack_properties["scheme"],
          :cloudstack_api_key => @cloudstack_properties["api_key"],
          :cloudstack_secret_access_key=> @cloudstack_properties["secret_access_key"]
      }
      @cloudstack = Fog::Compute.new(cloudstack_params)
      registry_endpoint = @registry_properties["endpoint"]
      registry_user = @registry_properties["user"]
      registry_password = @registry_properties["password"]
      @registry = RegistryClient.new(registry_endpoint,
                                     registry_user,
                                     registry_password)
      @metadata_lock = Mutex.new
    end

    ##
    # Creates a new CloudStack Image using stemcell image.
    # @param [String] image_path local filesystem path to a stemcell image
    # @param [Hash] cloud_properties CPI-specific properties
    #
    def create_stemcell(image_path, cloud_properties)
      with_thread_name("create_stemcell(#{image_path}...)") do
        #1 name the template's name.
        if cloud_properties["name"] && cloud_properties["version"]
          image_name = cloud_properties["name"] + "-" + cloud_properties["version"]
        else
          image_name = "BOSH-#{generate_unique_name}"
        end
        displaytext = image_name
        cloud_properties = cloud_properties.merge(:display_text => displaytext)
        #2 merge cloud_properties with undefined parameters.
        availability_zone = @cloudstack.zones.find { |z| z.name == @default_availability_zone }
        if availability_zone.nil?
          cloud_error("CloudStack CPI: zone #{@default_availability_zone} not found")
        end
        zone_id = availability_zone.id

        os_types = @cloudstack.ostypes.all
        os_type_id = os_types[0].id
        format = "QCOW2"
        hypervisor = "KVM"
        is_featured = "true"


        cloud_properties = cloud_properties.merge(:zone_id => zone_id, :os_type_id => os_type_id, :format => format)
        cloud_properties = cloud_properties.merge(:hypervisor => hypervisor, :is_featured => is_featured)
        @logger.info("cloud_properties are merged.")
        #current_dir = Dir.pwd
        Dir.mktmpdir do |tmp_dir|
          #get 'img_dir'
          unpack_image(tmp_dir, image_path)
          img_path=File.join(tmp_dir, "root.qcow2")
          @logger.info("Image_path now is: #{img_path}")
          #rename 'root.qcow2' to '<uuid>.qcow2'
          unique_name=generate_unique_name
          renamed_img_path="#{File.dirname(img_path)}/#{unique_name}.qcow2"
          FileUtils.mv("#{img_path}", "#{renamed_img_path}")

          #uses{#serverip}:{#container_path} scp
          #stemcell_server_container records absolute path to the container folder.
          stemcell_server_ip=@stemcell_server_params["stemcell_server_ip"]
          stemcell_server_username=@stemcell_server_params["stemcell_server_username"]
          stemcell_server_password=@stemcell_server_params["stemcell_server_password"]
          stemcell_server_container_path=@stemcell_server_params["stemcell_server_container_path"]
          stemcell_server_url_path=@stemcell_server_params["stemcell_server_url_path"]
          @logger.info("Start scp. stemcell_server_ip:#{stemcell_server_ip}")
          Net::SCP.start(stemcell_server_ip, stemcell_server_username, :password => stemcell_server_password,
                         :config => false, :user_known_hosts_file => [], :keys => []) do |scp|
            scp.upload!( renamed_img_path, stemcell_server_container_path )
          end
          #Guarantee scp is successful.
          if $?.exitstatus != 0
            cloud_error("Failed to uploading stemcell. SCP is failed")
          end

          #Join stemcell url. stemcell_server_ip should be a 32-bit ip address.
          #stemcell_server_url_path excludes the first slash(though unnecessary).
          url = "http://#{stemcell_server_ip}/#{stemcell_server_url_path}/#{unique_name}.qcow2"
          @logger.info("Url has generated: #{url}.")

          image = @cloudstack.images.new(cloud_properties.merge(:url => url))
          data = image.register
          @logger.info("Start upload image.data:#{data.inspect}")
          start_status = image.status
          @logger.info("start_status:#{start_status}")
          wait_resource(image, start_status, :"download complete", :status)
          image.id.to_s
        end
      end
    end

    ##
    # Deletes a stemcell
    # @param [String] stemcell stemcell id that was once returned by {#create_stemcell}
    #
    def delete_stemcell(stemcell_id)
      with_thread_name("delete_stemcell(#{stemcell_id})") do
        @logger.info("Deleting `#{stemcell_id}' stemcell")
        image = @cloudstack.images.get(stemcell_id)
        image.destroy
      end
    end

    ##
    # Creates an CloudStack server and waits until it's in running state
    # @param [String] agent_id Agent id associated with new VM
    # @param [String] stemcell_id AMI id that will be used to power on new server
    # @param [Hash] resource_pool Resource pool specification
    # @param [Hash] network_spec Network specification, if it contains security groups they must be existing
    # @param [optional, Array] disk_locality List of disks that might be attached to this server in the future,
    #  can be used as a placement hint (i.e. server will only be created if resource pool availability zone is
    #  the same as disk availability zone)
    # @param [optional, Hash] environment Data to be merged into agent settings
    # @return [String] created server id
    def create_vm(agent_id, stemcell_id, resource_pool,
        network_spec = nil, disk_locality = nil, environment = nil)
      with_thread_name("create_vm(#{agent_id}, ...)") do
        network_configurator = NetworkConfigurator.new(network_spec)

        server_name = "vm-#{generate_unique_name}"
        userdata = @registry.endpoint

        if disk_locality
          # TODO: use as hint for availability zones
          @logger.debug("Disk locality is ignored by CloudStack CPI")
        end

        image = @cloudstack.images.find { |i| i.id == stemcell_id }
        if image.nil?
          cloud_error("CloudStack CPI: image #{stemcell_id} not found")
        end

        flavor = @cloudstack.flavors.find { |f| f.name == resource_pool["instance_type"] }
        if flavor.nil?
          cloud_error("CloudStack CPI: flavor #{resource_pool["instance_type"]} not found")
        end

        #CloudStack does not have a "ephemeral" volume as OpenStack,so we attach a volume to the VM when it
        #starts up and this volume acts as the "ephemeral" volume.
        ephemeral_volume_offering = @cloudstack.disk_offerings.find { |d| d.name == resource_pool["ephemeral_volume_type"] }
        if ephemeral_volume_offering.nil?
          cloud_error("CloudStack CPI: volume #{resource_pool["ephemeral_volume_type"]} not found")
        end

        zone = @cloudstack.zones.find { |z| z.name == resource_pool["availability_zone"] }
        if zone.nil?
          cloud_error("CloudStack CPI: zone #{resource_pool["availability_zone"]} not found")
        end

        network = @cloudstack.networks.find { |n| n.name == resource_pool["network_name"] }
        if network.nil?
          cloud_error("CloudStack CPI: network #{resource_pool["network"]} not found")
        end


        server_params = {
            :zone_id => zone.id,
            :image_id => image.id,
            :flavor_id => flavor.id,
            :disk_offering_id => ephemeral_volume_offering.id,
            :network_ids => network.id,
            :display_name => server_name,
            :key_pair => resource_pool["key_name"] || @default_key_name,
            :user_data => Base64.encode64(userdata)
        }


        @logger.info("Creating new server...")
        server = @cloudstack.servers.create(server_params)
        state = cloudstack.servers.find { |s| s.id == server.id}.state

        @logger.info("Creating new server `#{server.id}', state is `#{state}'")
        wait_resource(server, state, :running, :state)

        @logger.info("Configuring network for `#{server.id}'")
        network_configurator.configure(@cloudstack, server)

        @logger.info("Updating server settings for `#{server.id}'")
        settings = initial_agent_settings(server_name, agent_id, network_spec, environment)
        @registry.update_settings(server.id, settings)

        server.id.to_s
      end
    end

    ##
    # Terminates an cloudstack server and waits until it reports as terminated
    # @param [String] server_id Running cloudstack server id
    def delete_vm(server_id)
      with_thread_name("delete_vm(#{server_id})") do
        server = @cloudstack.servers.get(server_id)
        @logger.info("Deleting server `#{server_id}'")
        if server
          state = server.state

          @logger.info("Deleting server `#{server.id}', state is `#{state}'")
          server.destroy
          wait_resource(server, state, :destroyed, :state)

          @logger.info("Deleting server settings for `#{server.id}'")
          @registry.delete_settings(server.id)
        end
      end
    end

    ##
    # Reboots an cloudstack Server
    # @param [String] server_id Running cloudstack server id
    def reboot_vm(server_id)
      with_thread_name("reboot_vm(#{server_id})") do
        server = @cloudstack.servers.get(server_id)
        state = server.state

        @logger.info("Rebooting server `#{server.id}', state is `#{state}'")
        reboot_job = server.reboot
        cost_time = reboot_job.wait_for { ready? }
        if cost_time
          @logger.info("Server `#{server.id}' is rebooted after #{cost_time[:duration]}s")
        else
          cloud_error("Reboot server `#{server.id}' failed")
        end

        #server.reboot
        #wait_resource(server, state, :running, :state)
      end
    end

    ##
    # Configures networking on existing cloudstack server
    # @param [String] server_id Running cloudstack server id
    # @param [Hash] network_spec raw network spec passed by director
    def configure_networks(server_id, network_spec)
      with_thread_name("configure_networks(#{server_id}, ...)") do
        @logger.info("Configuring `#{server_id}' to use the following " \
                     "network settings: #{network_spec.pretty_inspect}")

        server = @cloudstack.servers.get(server_id)
        network_configurator = NetworkConfigurator.new(network_spec)
        network_configurator.configure(@cloudstack, server)

        update_agent_settings(server) do |settings|
          settings["networks"] = network_spec
        end
      end
    end

    ##
    # Creates a new cloudstack volume
    # @param [Integer] size disk size in MiB
    # @param [optional, String] server_id vm id of the VM that this disk will be attached to
    # @return [String] created cloudstack volume id
    def create_disk(size, server_id = nil)
      with_thread_name("create_disk(#{size}, #{server_id})") do
        unless size.kind_of?(Integer)
          raise ArgumentError, "disk size needs to be an integer"
        end

        if (size < 1024)
          cloud_error("cloudstack CPI minimum disk size is 1 GiB")
        end

        if (size > 1024 * 1000)
          cloud_error("cloudstack CPI maximum disk size is 1 TiB")
        end
        if server_id
          server = @cloudstack.servers.get(server_id)
          availability_zone_id = server.zone_id
        else
          availability_zone = @cloudstack.zones.find { |z| z.name == @default_availability_zone }
          if availability_zone.nil?
            cloud_error("CloudStack CPI: zone #{@default_availability_zone} not found")
          end
          availability_zone_id = availability_zone.id
        end
        disk_offering = @cloudstack.disk_offerings.find { |d| d.name == "Custom" }
        if disk_offering.nil?
          cloud_error("CloudStack CPI: disk offering 'Custom' not found")
        end
        volume_params = {
            :name => "volume-#{generate_unique_name}",
            :size => (size / 1024.0).ceil,
            :zone_id => availability_zone_id,
            :disk_offering_id => disk_offering.id
        }

        @logger.info("Creating new volume...")
        volume = @cloudstack.volumes.create(volume_params)
        state = @cloudstack.volumes.find { |v| v.id == volume.id}.state

        @logger.info("Creating new volume `#{volume.id}', state is `#{state}'")
        wait_resource(volume, state, :allocated)

        volume.id.to_s
      end
    end

    ##
    # Deletes an cloudstack volume
    # @param [String] disk_id volume id
    def delete_disk(disk_id)
      with_thread_name("delete_disk(#{disk_id})") do
        volume = @cloudstack.volumes.get(disk_id)
        state = volume.state

        if volume.server_id
          server = @cloudstack.servers.get(volume.server_id)
          detach_volume(server, volume)
        end

        #cloud_error("Cannot delete volume `#{disk_id}' because it has been attached to VM `#{volume.server_id}'") if volume.server_id

        @logger.info("Deleting volume `#{disk_id}', state is `#{state}'")
        success = volume.destroy
        if success
          @logger.info(" Volume `#{disk_id}' is deleted")
        end
      end
    end

    ##
    # Attaches an cloudstack volume to an cloudstack server
    # @param [String] server_id Running cloudstack server id
    # @param [String] disk_id volume id
    def attach_disk(server_id, disk_id)
      with_thread_name("attach_disk(#{server_id}, #{disk_id})") do
        server = @cloudstack.servers.get(server_id)
        volume = @cloudstack.volumes.get(disk_id)

        device_id = attach_volume(server, volume)

        update_agent_settings(server) do |settings|
          settings["disks"] ||= {}
          settings["disks"]["persistent"] ||= {}
          settings["disks"]["persistent"][disk_id] = device_id
        end
      end
    end

    ##
    # Detaches an cloudstack volume from an cloudstack server
    # @param [String] server_id Running cloudstack server id
    # @param [String] disk_id volume id
    def detach_disk(server_id, disk_id)
      with_thread_name("detach_disk(#{server_id}, #{disk_id})") do
        server = @cloudstack.servers.get(server_id)
        volume = @cloudstack.volumes.get(disk_id)

        detach_volume(server, volume)

        update_agent_settings(server) do |settings|
          settings["disks"] ||= {}
          settings["disks"]["persistent"] ||= {}
          settings["disks"]["persistent"].delete(disk_id)
        end
      end
    end

    ##
    # Validates the deployment
    # @api not_yet_used
    def validate_deployment(old_manifest, new_manifest)
      not_implemented(:validate_deployment)
    end

    private

    ##
    # Generates initial agent settings. These settings will be read by agent
    # from cloudstack registry (also a BOSH component) on a target server. Disk
    # conventions for cloudstack are:
    # system disk: /dev/sda
    # cloudstack volumes can be configured to map to other device names later (vdc
    # through vdz, also some kernels will remap vd* to xvd*).
    #
    # @param [String] agent_id Agent id (will be picked up by agent to
    #   assume its identity
    # @param [Hash] network_spec Agent network spec
    # @param [Hash] environment
    # @return [Hash]
    def initial_agent_settings(server_name, agent_id, network_spec, environment)
      settings = {
          "vm" => {
              "name" => server_name
          },
          "agent_id" => agent_id,
          "networks" => network_spec,
          "disks" => {
              "system" => "/dev/sda",
              "ephemeral" => "/dev/vda",
              "persistent" => {}
          }
      }

      settings["env"] = environment if environment
      settings.merge(@agent_properties)
    end

    def update_agent_settings(server)
      unless block_given?
        raise ArgumentError, "block is not provided"
      end

      # TODO uncomment to test registry
      @logger.info("Updating server settings for `#{server.id}'")
      settings = @registry.read_settings(server.id)
      yield settings
      @registry.update_settings(server.id, settings)
    end

    def generate_unique_name
      UUIDTools::UUID.random_create.to_s
    end

    ##
    # Attaches an cloudstack volume to an cloudstack server
    # @param [Fog::Compute::cloudstack::Server] server cloudstack server
    # @param [Fog::Compute::cloudstack::Volume] volume cloudstack volume
    def attach_volume(server, volume)
      @logger.info("Attaching volume `#{volume.id}' to `#{server.id}'")
      attach_job = volume.attach(server)
      cost_time = attach_job.wait_for { ready? }
      if cost_time
        @logger.info("The volume `#{volume.id}' is attached to server `#{server.id}' after #{cost_time[:duration]}s ")
      else
        cloud_error("Attach volume `#{volume.id}' failed")
      end
      device_id = @cloudstack.volumes.get(volume.id).device_id
    end

    ##
    # Detaches an cloudstack volume from an cloudstack server
    # @param [Fog::Compute::cloudstack::Server] server cloudstack server
    # @param [Fog::Compute::cloudstack::Volume] volume cloudstack volume
    def detach_volume(server, volume)
      if volume.type == 'ROOT'
        cloud_error("Cannot detach Disk `#{volume.id}' because it is a ROOT disk")
      end
      if volume.server_id != server.id
        cloud_error("The volume `#{volume.id}' is not attached to server `#{server.id}'")
      end

      state = volume.state
      @logger.info("Detaching volume `#{volume.id}' from `#{server.id}', state is `#{state}'")
      detach_job = volume.detach
      cost_time = detach_job.wait_for { ready? }
      if cost_time
        @logger.info("The volume `#{volume.id}' is detached from server `#{server.id}' after #{cost_time[:duration]}s ")
      else
        cloud_error("Detach volume `#{volume.id}' failed")
      end

    end

    ##
    # Uploads a new image to cloudstack via Glance
    # @param [Hash] image_params Image params
    def upload_image(image_params)
      @logger.info("Creating new image...")
      image = @glance.images.create(image_params)
      state = image.status

      @logger.info("Creating new image `#{image.id}', state is `#{state}'")
      wait_resource(image, state, :active)

      image.id.to_s
    end

    ##
    # Reads current server id from cloudstack metadata. We are assuming
    # server id cannot change while current process is running
    # and thus memoizing it.
    def current_server_id
      @metadata_lock.synchronize do
        return @current_server_id if @current_server_id

        client = HTTPClient.new
        client.connect_timeout = METADATA_TIMEOUT
        # Using 169.254.169.254 is an cloudstack convention for getting
        # server metadata
        uri = "http://169.254.169.254/latest/instance-id"

        response = client.get(uri)
        unless response.status == 200
          cloud_error("Server metadata endpoint returned HTTP #{response.status}")
        end

        instance_id = response.body
        unless instance_id
          cloud_error("Invalid response from #{uri}")
        end

        @current_server_id = instance_id
      end

    rescue HTTPClient::TimeoutError
      cloud_error("Timed out reading server metadata, " \
                  "please make sure CPI is running on an Cloudstack server")
    end

    def find_device(vd_name)
      xvd_name = vd_name.gsub(/^\/dev\/vd/, "/dev/xvd")

      DEVICE_POLL_TIMEOUT.times do
        if File.blockdev?(vd_name)
          return vd_name
        elsif File.blockdev?(xvd_name)
          return xvd_name
        end
        sleep(1)
      end

      cloud_error("Cannot find cloudstack volume on current server")
    end

    def unpack_image(tmp_dir, image_path)
      output = `tar -C #{tmp_dir} -xzf #{image_path} 2>&1`
      if $?.exitstatus != 0
        cloud_error("Failed to unpack stemcell root image" \
                    "tar exit status #{$?.exitstatus}: #{output}")
      end
      @logger.info("Unpack finished. template file is in #{tmp_dir}")
      FileUtils.mv("#{tmp_dir}/root.img", "#{tmp_dir}/root.qcow2")
      root_image = File.join(tmp_dir, "root.qcow2")
      @logger.info("root_image is #{root_image}")
      unless File.exists?(root_image)
        cloud_error("Root image is missing from stemcell archive")
      end
    end

    ##
    # Checks if options passed to CPI are valid and can actually
    # be used to create all required data structures etc.
    #
    def validate_options
      unless @options.has_key?("cloudstack") &&
          @options["cloudstack"].is_a?(Hash) &&
          @options["cloudstack"]["host"] &&
          @options["cloudstack"]["port"] &&
          @options["cloudstack"]["scheme"] &&
          @options["cloudstack"]["api_key"] &&
          @options["cloudstack"]["secret_access_key"]
        raise ArgumentError, "Invalid cloudstack configuration parameters"
      end

      unless @options.has_key?("registry") &&
          @options["registry"].is_a?(Hash) &&
          @options["registry"]["endpoint"] &&
          @options["registry"]["user"] &&
          @options["registry"]["password"]
        raise ArgumentError, "Invalid registry configuration parameters"
      end
    end

  end

end
