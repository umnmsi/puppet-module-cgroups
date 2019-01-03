require 'spec_helper'
describe 'cgroups::group' do
  let(:title) { 'rspec/test' }
  let(:facts) do
    {
      :osfamily                  => 'RedHat',
      :operatingsystemrelease    => '7.1',
      :operatingsystemmajrelease => '7',
    }
  end
  context 'with defaults for all parameters' do
    content = <<-END.gsub(/^\s+\|/, '')
      |# This file is being maintained by Puppet.
      |# DO NOT EDIT
      |
      |group rspec/test {
      |
      |}
    END

    # test includes filesystem compatible file name generation of title (replace / with -)
    it do
      should contain_file('/etc/cgconfig.d/rspec-test.conf').with({
        'ensure'  => 'file',
        'notify'  => 'Service[cgconfig]',
        'content' => content,
      })
    end
  end

  context 'with template' do
    let(:title) { 'rspec/%u' }

    content = <<-END.gsub(/^\s+\|/, '')
      |# This file is being maintained by Puppet.
      |# DO NOT EDIT
      |
      |template rspec/%u {
      |
      |}
    END

    it do
      should contain_file('/etc/cgconfig.d/rspec-%u.conf').with({
        'ensure'  => 'file',
        'notify'  => 'Service[cgconfig]',
        'content' => content,
      })
    end
  end


  context 'with all parameters set to valid values' do
    let(:params) do
      {
        :permissions => {
          'task' => {
            'uid' => 'root',
            'gid' => 'mgw-all'
          },
          'admin' => {
            'uid' => 'root',
            'gid' => 'mgw-all'
          }
        },
        :controllers => {
          'cpu' => {
            'cpuset.mems' => '0',
            'cpuset.cpus' => '0,1'
          }
        },
        :target_path => '/specific/path',
      }
    end
    # test includes alphabetical sorting of values in the template
    content = <<-END.gsub(/^\s+\|/, '')
      |# This file is being maintained by Puppet.
      |# DO NOT EDIT
      |
      |group rspec/test {
      |
      |  perm {
      |    admin  {
      |      gid = mgw-all;
      |      uid = root;
      |    }
      |    task  {
      |      gid = mgw-all;
      |      uid = root;
      |    }
      |  }
      |
      |  cpu {
      |    cpuset.cpus = 0,1;
      |    cpuset.mems = 0;
      |  }
      |
      |}
    END

    it do
      should contain_file('/specific/path/rspec-test.conf').with({
        'ensure'  => 'file',
        'notify'  => 'Service[cgconfig]',
        'content' => content,
      })
    end
  end

  context 'with permissions set to valid hash' do
    let(:params) do
      {
        :permissions => {
          'rspec' => {
            'uid' => 'rpsec',
            'gid' => 'test',
          },
        },
      }
    end
    content = <<-END.gsub(/^\s+\|/, '')
      |# This file is being maintained by Puppet.
      |# DO NOT EDIT
      |
      |group rspec/test {
      |
      |  perm {
      |    rspec  {
      |      gid = test;
      |      uid = rpsec;
      |    }
      |  }
      |
      |}
    END

    it { should contain_file('/etc/cgconfig.d/rspec-test.conf').with_content(content) }
  end

  context 'with controllers set to valid hash' do
    let(:params) do
      {
        :controllers => {
          'cpu' => {
            'cpuset.mems' => '242',
            'cpuset.cpus' => '2,42',
          },
        },
      }
    end
    content = <<-END.gsub(/^\s+\|/, '')
      |# This file is being maintained by Puppet.
      |# DO NOT EDIT
      |
      |group rspec/test {
      |
      |  cpu {
      |    cpuset.cpus = 2,42;
      |    cpuset.mems = 242;
      |  }
      |
      |}
    END

    it { should contain_file('/etc/cgconfig.d/rspec-test.conf').with_content(content) }
  end

  context 'with target_path set to valid string </other/path>' do
    let(:params) { { :target_path => '/other/path' } }

    it { should contain_file('/other/path/rspec-test.conf') }
  end

  describe 'variable type and content validations' do
    # set needed custom facts and variables
    let(:facts) do
      {
        :operatingsystemmajrelease => '6',
        :operatingsystemrelease    => '6.4',
        :osfamily                  => 'RedHat',
      }
    end
    let(:mandatory_params) do
      {
        #:param => 'value',
      }
    end

    validations = {
      'absolute_path' => {
        :name    => %w(target_path),
        :valid   => %w(/absolute/filepath /absolute/directory/),
        :invalid => ['string', %w(array), { 'ha' => 'sh' }, 3, 2.42, true, false, nil],
        :message => 'is not an absolute path',
      },
      'hash' => {
        :name    => %w(permissions controllers),
        :valid   => ['t' => { 'ha' => 'sh' }],
        :invalid => ['string', %w(array), 3, 2.42, true, false, nil],
        :message => 'is not a Hash',
      },
    }

    validations.sort.each do |type, var|
      var[:name].each do |var_name|
        var[:params] = {} if var[:params].nil?
        var[:valid].each do |valid|
          context "when #{var_name} (#{type}) is set to valid #{valid} (as #{valid.class})" do
            let(:params) { [mandatory_params, var[:params], { :"#{var_name}" => valid, }].reduce(:merge) }
            it { should compile }
          end
        end

        var[:invalid].each do |invalid|
          context "when #{var_name} (#{type}) is set to invalid #{invalid} (as #{invalid.class})" do
            let(:params) { [mandatory_params, var[:params], { :"#{var_name}" => invalid, }].reduce(:merge) }
            it 'should fail' do
              expect { should contain_class(subject) }.to raise_error(Puppet::Error, /#{var[:message]}/)
            end
          end
        end
      end # var[:name].each
    end # validations.sort.each
  end # describe 'variable type and content validations'
end
