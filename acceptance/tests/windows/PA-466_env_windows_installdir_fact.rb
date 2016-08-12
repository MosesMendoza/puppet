# (PA-466) The env_windows_installdir fact is set as an environment variable
# fact via environment.bat on Windows systems. Test to ensure it is both
# present and accurate.
test_name 'PA-466: Ensure env_windows_installdir fact is present and correct' do

  confine :to, :platform => 'windows'

  agents.each do |agent|
    step "test for presence/accurance of env_windows_installdir fact on #{agent}" do
      on agent, puppet('facts') do
        assert_match(/"env_windows_installdir": "C:\\\\Program Files\\\\Puppet Labs\\\\Puppet"/, stdout, "env_windows_installdir fact did not match expected output")
      end
    end

    step "test for presence/accurance of domain fact on #{agent}" do
      on agent, puppet('facts') do
        assert_match(/"domain": "delivery.puppetlabs.net"/, stdout, "env_windows_installdir fact did not match expected output")
      end
    end
  end
end
