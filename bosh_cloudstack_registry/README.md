# BOSH CloudStack Registry
Copyright (c) 2009-2013 Zju, Inc.

## Usage

    bin/migrate [<options>]
        -c, --config FILE  CloudStack Registry configuration file

    bin/cloudstack_registry [<options>]
        -c, --config FILE  CloudStack Registry configuration file

## Configuration

These options are passed to the CloudStack Registry when it is instantiated.

### Registry options

These are the options for the Registry HTTP server (by default server is
bound to address 0.0.0.0):

* `port` (required)
  Registry port
* `user` (required)
  Registry user (for HTTP Basic authentication)
* `password` (required)
  Registry password (for HTTP Basic authentication)

### Database options

These are the options for the database connection where registry will store
server properties:

* `database` (required)
  DB connection URI
* `max_connections` (required)
  Maximum size of the connection pool
* `pool_timeout` (required)
  Number of seconds to wait if a connection cannot be acquired before
  raising an error

### CloudStack options

These are the credentials to connect to CloudStack services:

* `auth_url` (required)
  URL of the CloudStack Identity endpoint to connect to
* `username` (required)
  CloudStack user name
* `api_key` (required)
  CloudStack API key
* `tenant` (required)
  CloudStack tenant name
* `region` (optional)
  CloudStack region

## Example

This is a sample of an CloudStack Registry configuration file:

    ---
    loglevel: debug

    http:
      port: 25695
      user: admin
      password: admin

    db:
      database: "sqlite:///:memory:"
      max_connections: 32
      pool_timeout: 10

    cloudstack:
      auth_url: "http://127.0.0.1:5000/v2.0/tokens"
      username: foo
      api_key: bar
      tenant: foo
      region:
