require 'puppet/acceptance/temp_file_utils'
extend Puppet::Acceptance::TempFileUtils

# ensure a version file is created according to the puppet-agent path specification:
# https://github.com/puppetlabs/puppet-specifications/blob/master/file_paths.md

test_name 'PA-466: Ensure version file is created on agent' do

  skip_test 'requires version file which is created by AIO' if [:gem].include?(@options[:type])

  #step "test for existence of version file" do
  #  agents.each do |agent|
  #    version_file = agent[:platform] =~ /windows/ ?
  #      'C:/Program Files/Puppet Labs/Puppet/VERSION' :
  #      '/opt/puppetlabs/puppet/VERSION'

  #    if !file_exists?(agent, version_file)
  #      fail_test("Failed to find version file #{version_file} on agent #{agent}")
  #    end
  #  end
  #end
  step "test for existence of a kmnown file" do
    agents.each do |agent|
      version_file = agent[:platform] =~ /windows/ ?
        'C:/Program Files' :
        '/opt/puppetlabs/puppet/VERSION'

      if !dir_exists?(agent, version_file)
        fail_test("Failed to find version file #{version_file} on agent #{agent}")
      end
    end
  end
end

