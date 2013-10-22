# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Infrastructure::Cloudstack::Registry
    class << self

      API_TIMEOUT     = 86400 * 3
      CONNECT_TIMEOUT = 30
      SERVER_DATA_URI = "http://169.254.169.254/latest"

      def get_uri(uri)
        client = HTTPClient.new
        client.send_timeout = API_TIMEOUT
        client.receive_timeout = API_TIMEOUT
        client.connect_timeout = CONNECT_TIMEOUT

        response = client.get(SERVER_DATA_URI + uri)
        unless response.status == 200
          raise(LoadSettingsError, "Server metadata endpoint returned " \
                      "HTTP #{response.status}")
        end

        response.body
      rescue HTTPClient::BadResponseError => e
        raise(LoadSettingsError,
              "Received bad HTTP response for #{uri}: #{e.inspect}")
      rescue HTTPClient::TimeoutError
        raise(LoadSettingsError, "Timed out reading uri #{uri}, " \
                    "please make sure agent is running on CloudStack server")
      rescue URI::Error, SocketError, Errno::ECONNREFUSED, SystemCallError => e
        raise(LoadSettingsError,
              "Error requesting current server id from #{uri} #{e.inspect}")
      end

      ##
      # Reads current server id from CloudStack metadata. We are assuming
      # server id cannot change while current process is running
      # and thus memoizing it.
      def current_server_id
        return @current_server_id if @current_server_id
        @current_server_id = get_uri("/instance-id")
      end

      def get_json_from_url(url)
        client = HTTPClient.new
        client.send_timeout = API_TIMEOUT
        client.receive_timeout = API_TIMEOUT
        client.connect_timeout = CONNECT_TIMEOUT

        headers = {"Accept" => "application/json"}
        response = client.get(url, {}, headers)

        if response.status != 200
          raise(LoadSettingsError,
                "Cannot read settings for `#{url}' from registry, " \
                "got HTTP #{response.status}")
        end

        body = Yajl::Parser.parse(response.body)
        unless body.is_a?(Hash)
          raise(LoadSettingsError,
                "Invalid response from #{url} , Hash expected, " \
                "got #{body.class}: #{body}")
        end

        body

      rescue HTTPClient::BadResponseError => e
        raise(LoadSettingsError,
              "Received bad HTTP response from server registry: #{e.inspect}")
      rescue HTTPClient::TimeoutError
        raise(LoadSettingsError,
              "Timed out reading json from #{url}, " \
              "please make sure agent is running on CloudStack server")
      rescue URI::Error, SocketError, Errno::ECONNREFUSED, SystemCallError => e
        raise(LoadSettingsError,
              "Error requesting registry information #{e.inspect}")
      rescue Yajl::ParseError => e
        raise(LoadSettingsError,
              "Cannot parse settings for from registry #{e.inspect}")
      end

      def get_registry_endpoint
        user_data = get_uri("/user-data")
        unless user_data
          raise("Cannot parse user data for endpoint")
        end
        Bosh::Agent::Config.logger.info("got user_data: #{user_data}")
        user_data
      end

      def get_openssh_key
        get_uri("/public-keys")
      end

      def get_settings
        @registry_endpoint ||= get_registry_endpoint
        url = "#{@registry_endpoint}/servers/#{current_server_id}/settings"
        body = get_json_from_url(url)

        settings = Yajl::Parser.parse(body["settings"])
        unless settings.is_a?(Hash)
          raise(LoadSettingsError, "Invalid settings format, " \
                "Hash expected, got #{settings.class}: #{settings}")
        end

        settings

      rescue Yajl::ParseError
        raise(LoadSettingsError,
              "Cannot parse settings from registry #{@registry_endpoint}")
      end

    end
  end
end
