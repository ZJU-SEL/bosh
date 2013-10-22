# Copyright (c) 2012 Piston Cloud Computing, Inc.

module Bosh::CloudStackCloud

  module Helpers

    DEFAULT_TIMEOUT = 3600

    #
    # Raises CloudError exception
    #
    def cloud_error(message)
      @logger.error(message) if @logger
      raise Bosh::Clouds::CloudError, message
    end

    #
    # Waits for a resource to be on a target state
    #
    def wait_resource(resource, start_state, target_state, state_method = :state, timeout = DEFAULT_TIMEOUT)

      started_at = Time.now
      state = resource.send(state_method).downcase rescue state_method
      desc = resource.class.name.split("::").last.to_s + " " + resource.id.to_s
      failures = 0

      while state.to_sym != target_state
        duration = Time.now - started_at

        if duration > timeout
          cloud_error("Timed out waiting for #{desc} to be #{target_state}")
        end

        @logger.debug("Waiting for #{desc} to be #{target_state} (#{duration})") if @logger

        # This is not a very strong convention, but some resources
        # have 'error' and 'failed' states, we probably don't want to keep
        # waiting if we're in these states.
        if state == :error
          cloud_error("#{desc} state is #{state}, expected #{target_state}")
          break
        end

        sleep(1)

        if resource.reload.nil?
          failures += 1
          if failures > 3
            cloud_error("Reload failed, #{desc} went away.")
            break
          end
        else
          failures = 0
          state = resource.send(state_method).downcase rescue state_method
        end
      end

      @logger.info("#{desc} is #{target_state} after #{Time.now - started_at}s") if @logger
    end

  end

end
