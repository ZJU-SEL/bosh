require 'spec_helper'
require 'bosh/dev/bat_helper'

module Bosh::Dev
  describe BatHelper do
    include FakeFS::SpecHelpers

    let(:infrastructure_name) { 'FAKE_INFRASTRUCTURE_NAME' }
    let(:fake_infrastructure) { instance_double('Bosh::Stemcell::Infrastructure::Base', name: infrastructure_name, light?: light) }
    let(:light) { false }
    let(:build) { instance_double('Bosh::Dev::Build', download_stemcell: nil) }
    let(:network_type) { nil }

    subject { BatHelper.new(infrastructure_name, network_type, build) }

    before do
      Bosh::Stemcell::Infrastructure.should_receive(:for).and_return(fake_infrastructure)
    end

    describe '#initialize' do
      it 'sets infrastructre' do
        expect(subject.infrastructure).to eq(fake_infrastructure)
      end
    end

    describe '#run_rake' do
      let(:spec_system_micro_task) { instance_double('Rake::Task', invoke: nil) }
      let(:rake_task_to_invoke) { "spec:system:#{infrastructure_name}:micro" }

      before do
        ENV.delete('BAT_INFRASTRUCTURE')
        Rake::Task.stub(:[]).with(rake_task_to_invoke).and_return(spec_system_micro_task)

        FileUtils.stub(rm_rf: nil, mkdir_p: nil)
      end

      after do
        ENV.delete('BAT_INFRASTRUCTURE')
      end

      it 'removes the artifacts dir' do
        FileUtils.should_receive(:rm_rf).with(subject.artifacts_dir)

        subject.run_rake
      end

      it 'creates the microbosh deployments dir (which is contained within artifacts dir)' do
        FileUtils.should_receive(:mkdir_p).with(subject.micro_bosh_deployment_dir)

        subject.run_rake
      end

      it 'sets ENV["BAT_INFRASTRUCTURE"]' do
        expect(ENV['BAT_INFRASTRUCTURE']).to be_nil

        subject.run_rake

        expect(ENV['BAT_INFRASTRUCTURE']).to eq(infrastructure_name)
      end

      it 'downloads stemcells for the specified infrastructure' do
        build.should_receive(:download_stemcell).with(infrastructure: subject.infrastructure, name: 'bosh-stemcell', light: light, output_directory: '/tmp/ci-artifacts/FAKE_INFRASTRUCTURE_NAME/deployments')

        subject.run_rake
      end

      it 'invokes the spec:system:<infrastructure>:micro rake task' do
        spec_system_micro_task.should_receive(:invoke)

        subject.run_rake
      end

      context 'deploying to openstack' do
        let(:infrastructure_name) { 'openstack' }

        context 'manual network type' do
          let(:rake_task_to_invoke) { "spec:system:#{infrastructure_name}:deploy_micro_manual_net" }
          let(:network_type) { 'manual' }

          it 'invokes the spec:system:openstack:deploy_micro_manual_net rake task' do
            spec_system_micro_task.should_receive(:invoke)

            subject.run_rake
          end
        end

        context 'dynamic network type' do
          let(:rake_task_to_invoke) { "spec:system:#{infrastructure_name}:deploy_micro_dynamic_net" }
          let(:network_type) { 'dynamic' }

          it 'invokes the spec:system:openstack:deploy_micro_dynamic_net rake task' do
            spec_system_micro_task.should_receive(:invoke)

            subject.run_rake
          end
        end

        context 'no network type is passed' do
          let(:rake_task_to_invoke) { "spec:system:#{infrastructure_name}:micro" }
          let(:network_type) { nil }

          it 'invokes the spec:system:openstack:micro rake task' do
            spec_system_micro_task.should_receive(:invoke)

            subject.run_rake
          end
        end
      end
    end

    describe '#artifacts_dir' do
      %w[openstack vsphere aws].each do |i|
        let(:infrastructure_name) { i }

        its(:artifacts_dir) { should eq(File.join('/tmp', 'ci-artifacts', subject.infrastructure.name, 'deployments')) }
      end
    end

    describe '#micro_bosh_deployment_dir' do
      its(:micro_bosh_deployment_dir) { should eq(File.join(subject.artifacts_dir, subject.micro_bosh_deployment_name)) }
    end

    describe '#micro_bosh_deployment_name' do
      its(:micro_bosh_deployment_name) { should == 'microbosh' }
    end

    describe '#bosh_stemcell_path' do
      before do
        build.stub(:bosh_stemcell_path) do |infrastructure, artifacts_dir|
          expect(infrastructure.name).to eq(infrastructure_name)
          expect(artifacts_dir).to eq(subject.artifacts_dir)
          'fake bosh stemcell path'
        end
      end

      it 'delegates to the build' do
        expect(subject.bosh_stemcell_path).to eq('fake bosh stemcell path')
      end
    end
  end
end
