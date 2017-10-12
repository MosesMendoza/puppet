#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/ssl/certificate_revocation_list'

include PuppetSpec::Files

describe Puppet::SSL::CertificateRevocationList, :if => !Puppet.features.microsoft_windows? do

  def generate_certificates!(concurrency_volume)
    ca = Puppet::SSL::CertificateAuthority.new
    concurrency_volume.times do |i|
      ca.generate("host#{i}")
    end
  end

  def perform_concurrent_revocations(concurrency_volume)
    pids = []
    concurrency_volume.times do |i|
      pids << fork do
        ca = Puppet::SSL::CertificateAuthority.new
        ca.revoke("host#{i}")
      end
    end
    pids.each { |pid| Process.wait(pid) }
  end

  let(:temp_dir) { tmpdir("ca_integration_testing") }

  before do
    # Get a safe temporary file
    Puppet.settings[:confdir] = temp_dir
    Puppet.settings[:vardir] = temp_dir
    Puppet::SSL::Host.ca_location = :local
  end

  after do
    Puppet::SSL::Host.ca_location = :none
    # This is necessary so the terminus instances don't lie around.
    Puppet::SSL::Host.indirection.termini.clear
  end

  let(:concurrency_volume) { 2 }

  it "should be able to read in written out CRLs with no revoked certificates" do
    ca = Puppet::SSL::CertificateAuthority.new
    crl = Puppet::SSL::CertificateRevocationList.new("crl_in_testing")
    expect(crl.read(Puppet[:hostcrl])).to be_an_instance_of(OpenSSL::X509::CRL)
  end

  context "when handling concurrent access" do
    it "should be able to support safe concurrent write access to the CRL" do
      generate_certificates!(concurrency_volume)
      perform_concurrent_revocations(concurrency_volume)
      validator_ca = Puppet::SSL::CertificateAuthority.new
      # is this even a well-formed CRL?
      expect(validator_ca.crl.content).to be_an_instance_of(OpenSSL::X509::CRL)
      # did we actually revoke all the certs we wanted to?
      expect(validator_ca.crl.content.revoked.length).to eq(concurrency_volume)
    end
  end
end
