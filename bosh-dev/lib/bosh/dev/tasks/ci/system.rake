require 'bosh/dev/bat_helper'

namespace :ci do
  namespace :system do
    task :micro, [:infrastructure, :network_type = nil] do |_, args|
      Bosh::Dev::BatHelper.new(args.infrastructure, network_type).run_rake
    end
  end
end
