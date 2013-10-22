# BOSH cloudstack Cloud Provider Interface
# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

For online documentation see: http://rubydoc.info/gems/bosh_cloudstack_cpi/

## Options

These options are passed to the cloudstack CPI when it is instantiated.

### cloudstack options

* `auth_url` (required)
  URL of the cloudstack Identity endpoint to connect to
* `username` (required)
  cloudstack user name
* `api_key` (required)
  cloudstack API key
* `tenant` (required)
  cloudstack tenant name
* `region` (optional)
  cloudstack region
* `endpoint_type` (optional)
  cloudstack endpoint type for Glance
* `default_key_name` (required)
  default cloudstack ssh key name to assign to created virtual machines
* `default_security_group` (required)
  default cloudstack security group to assign to created virtual machines
* `private_key` (required)
  local path to the ssh private key, must match `default_key_name`

### Registry options

The registry options are passed to the cloudstack CPI by the BOSH director based on the settings in `director.yml`, but can be overridden if needed.

* `endpoint` (required)
  cloudstack registry URL
* `user` (required)
  cloudstack registry user
* `password` (required)
  rcloudstack egistry password

### Agent options

Agent options are passed to the cloudstack  CPI by the BOSH director based on the settings in `director.yml`, but can be overridden if needed.

### Resource pool options

These options are specified under `cloud_options` in the `resource_pools` section of a BOSH deployment manifest.

* `instance_type` (required)
  which type of instance (cloudstack flavor) the VMs should belong to
* `availability_zone` (optional)
  the cloudstack availability zone the VMs should be created in

### Network options

These options are specified under `cloud_options` in the `networks` section of a BOSH deployment manifest.

* `type` (required)
  can be either `dynamic` for a DHCP assigned IP by cloudstack, or `vip` to use a Floating IP (which needs to be already allocated)

## Example

This is a sample of how cloudstack specific properties are used in a BOSH deployment manifest:

    ---
    name: sample
    director_uuid: 38ce80c3-e9e9-4aac-ba61-97c676631b91

    ...

    networks:
      - name: nginx_network
        type: vip
        cloud_properties: {}
      - name: default
        type: dynamic
        cloud_properties:
          security_groups:
          - default

    ...

    resource_pools:
      - name: common
        network: default
        size: 3
        stemcell:
          name: bosh-stemcell
          version: 0.6.7
        cloud_properties:
          instance_type: m1.small

    ...

    properties:
      cloudstack:
        auth_url: http://pistoncloud.com/:5000/v2.0/tokens
        username: christopher
        api_key: QRoqsenPsNGX6
        tenant: Bosh
        region: us-west
        default_key_name: bosh
        default_security_groups: ["bosh"]
        private_key: /home/bosh/.ssh/bosh.pem
