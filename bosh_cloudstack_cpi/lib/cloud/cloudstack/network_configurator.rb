# Copyright (c) 2012 ZJU Cloud Computing, Inc.

module Bosh::CloudStackCloud
  ##
  # Represents CloudStack server network config. CloudStack server has single NIC
  # with dynamic IP address and (optionally) a single floating IP address
  # which server itself is not aware of (vip). Thus we should perform
  # a number of sanity checks for the network spec provided by director
  # to make sure we don't apply something CloudStack doesn't understand how to
  # deal with.
  #
  class NetworkConfigurator
    include Helpers

    ##
    # Creates new network spec
    #
    # @param [Hash] spec raw network spec passed by director
    # TODO Add network configuration examples
    def initialize(spec)
      unless spec.is_a?(Hash)
        raise ArgumentError, "Invalid spec, Hash expected, " \
                             "#{spec.class} provided"
      end

      @logger = Bosh::Clouds::Config.logger
      @dynamic_network = nil
      @vip_network = nil

      spec.each_pair do |name, spec|
        network_type = spec["type"]

        case network_type
        when "dynamic"
          if @dynamic_network
            cloud_error("More than one dynamic network for `#{name}'")
          else
            @dynamic_network = DynamicNetwork.new(name, spec)
          end
        when "vip"
          if @vip_network
            cloud_error("More than one vip network for `#{name}'")
          else
            @vip_network = VipNetwork.new(name, spec)
          end
        else
          cloud_error("Invalid network type `#{network_type}': CloudStack CPI " \
                      "can only handle `dynamic' and `vip' network types")
        end

      end

      if @dynamic_network.nil?
        cloud_error("At least one dynamic network should be defined")
      end
    end

    def configure(cloudstack, server)
      @dynamic_network.configure(cloudstack, server)

      if @vip_network
        @vip_network.configure(cloudstack, server)
      else
        # If there is no vip network we should disassociate any floating IP
        # currently held by server (as it might have had floating IP before)
        addresses = cloudstack.ipaddresses
        addresses.each do |address|
          if address.virtual_machine_id == server.id
            @logger.info("Disassociating floating IP `#{address.ip_address}' " \
                         "from server `#{server.id}'")
            static_nat_params = {
                :ip_address_id => address.id,
            }
            static_nat = cloudstack.nats.new(static_nat_params)
            static_nat_job = static_nat.disable
            cost_time = static_nat_job.wait_for { ready? }
            @logger.info("The floating IP #{address.ip_address} is disassociated after #{cost_time[:duration]}s")
            break
          end
        end
      end
    end

  end

end