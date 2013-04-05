require 'unit_helper'

require 'vagrant'
require 'vagrant-lxc/driver'

describe Vagrant::LXC::Driver do
  let(:name) { nil }
  subject { described_class.new(name) }

  describe 'container name validation' do
    let(:unknown_container) { described_class.new('unknown', cli) }
    let(:valid_container)   { described_class.new('valid', cli) }
    let(:new_container)     { described_class.new(nil) }
    let(:cli)               { fire_double('Vagrant::LXC::Driver::CLI', list: ['valid']) }

    it 'raises a ContainerNotFound error if an unknown container name gets provided' do
      expect {
        unknown_container.validate!
      }.to raise_error(Vagrant::LXC::Driver::ContainerNotFound)
    end

    it 'does not raise a ContainerNotFound error if a valid container name gets provided' do
      expect {
        valid_container.validate!
      }.to_not raise_error(Vagrant::LXC::Driver::ContainerNotFound)
    end

    it 'does not raise a ContainerNotFound error if nil is provider as name' do
      expect {
        new_container.validate!
      }.to_not raise_error(Vagrant::LXC::Driver::ContainerNotFound)
    end
  end

  describe 'creation' do
    let(:base_name)       { 'container-name' }
    let(:suffix)          { 'random-suffix' }
    let(:template_name)   { 'template-name' }
    let(:rootfs_tarball)  { '/path/to/cache/rootfs.tar.gz' }
    let(:public_key_path) { Vagrant.source_root.join('keys', 'vagrant.pub').expand_path.to_s }
    let(:cli)             { fire_double('Vagrant::LXC::Driver::CLI', :create => true, :name= => true) }

    subject { described_class.new(name, cli) }

    before do
      SecureRandom.stub(hex: suffix)
      subject.create base_name, 'template-name' => template_name, 'rootfs-tarball' => rootfs_tarball, 'template-opts' => { '--foo' => 'bar'}
    end

    it 'creates container with the right arguments' do
      cli.should have_received(:name=).with("#{base_name}-#{suffix}")
      cli.should have_received(:create).with(
        template_name,
        '--auth-key' => public_key_path,
        '--tarball'  => rootfs_tarball,
        '--foo'      => 'bar'
      )
    end
  end

  describe 'destruction' do
    let(:name) { 'container-name' }
    let(:cli)  { fire_double('Vagrant::LXC::Driver::CLI', destroy: true) }

    subject { described_class.new(name, cli) }

    before { subject.destroy }

    it 'delegates to cli object' do
      cli.should have_received(:destroy)
    end
  end

  describe 'start' do
    let(:config) { mock(:config, start_opts: ['a=1', 'b=2']) }
    let(:name)   { 'container-name' }
    let(:cli)    { fire_double('Vagrant::LXC::Driver::CLI', start: true) }

    subject { described_class.new(name, cli) }

    before do
      cli.stub(:transition_to).and_yield(cli)
    end

    it 'starts container with configured lxc settings' do
      cli.should_receive(:start).with(['a=1', 'b=2'], nil)
      subject.start(config)
    end

    it 'expects a transition to running state to take place' do
      cli.should_receive(:transition_to).with(:running)
      subject.start(config)
    end
  end

  describe 'halt' do
    let(:name) { 'container-name' }
    let(:cli)  { fire_double('Vagrant::LXC::Driver::CLI', shutdown: true) }

    subject { described_class.new(name, cli) }

    before do
      cli.stub(:transition_to).and_yield(cli)
    end

    it 'delegates to cli shutdown' do
      cli.should_receive(:shutdown)
      subject.halt
    end

    it 'expects a transition to running state to take place' do
      cli.should_receive(:transition_to).with(:stopped)
      subject.halt
    end
  end

  describe 'state' do
    let(:name)      { 'random-container-name' }
    let(:cli_state) { :something }
    let(:cli)       { fire_double('Vagrant::LXC::Driver::CLI', state: cli_state) }

    subject { described_class.new(name, cli) }

    it 'delegates to cli' do
      subject.state.should == cli_state
    end
  end

  describe 'assigned ip' do
    # This ip is set on the sample-ifconfig-output fixture
    let(:ip)              { "10.0.3.109" }
    let(:ifconfig_output) { File.read('spec/fixtures/sample-ifconfig-output') }
    let(:name)            { 'random-container-name' }
    let(:cli)             { fire_double('Vagrant::LXC::Driver::CLI', :attach => ifconfig_output) }

    subject { described_class.new(name, cli) }

    context 'when ip for eth0 gets returned from lxc-attach call' do
      it 'gets parsed from ifconfig output' do
        subject.assigned_ip.should == ip
        cli.should have_received(:attach).with('/sbin/ifconfig', '-v', 'eth0', namespaces: 'network')
      end
    end
  end
end
