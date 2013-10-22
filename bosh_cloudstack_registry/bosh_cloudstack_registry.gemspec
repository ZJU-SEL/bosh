# Copyright (c) 2009-2012 VMware, Inc.

version = File.read(File.expand_path('../../BOSH_VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.name         = "bosh_cloudstack_registry"
  s.version      = version
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH Cloudstack registry"
  s.description  = s.summary
  s.author       = "ZJU Vlis"
  s.homepage     = 'https://github.com/cloudfoundry/bosh'
  s.license      = 'Apache 2.0'
  s.email        = "alan90121@zju.edu.cn"
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3")

  s.files        = `git ls-files -- lib/* db/*`.split("\n") +
                   %w(README.md)
  s.require_path = "lib"
  s.bindir       = "bin"
  s.executables  = %w(cloudstack_registry migrate)

  s.add_dependency "sequel"
  s.add_dependency "sinatra"
  s.add_dependency "thin"
  s.add_dependency "yajl-ruby"
  s.add_dependency "fog", ">=1.9.0"
end
