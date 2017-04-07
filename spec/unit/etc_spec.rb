require 'puppet'
require 'spec_helper'

# The Ruby::Etc module is largely non-functional on Windows - many methods
# simply return nil regardless of input, the Etc::Group struct is not defined,
# and Etc::Passwd is missing fields
describe Puppet::Etc, :if => !Puppet.features.microsoft_windows? do
  let(:bin) { 'bin'.force_encoding(Encoding::ISO_8859_1) }
  let(:root) { 'root'.force_encoding(Encoding::ISO_8859_1) }
  let(:x) { 'x'.force_encoding(Encoding::ISO_8859_1) }
  let(:daemon) { 'daemon'.force_encoding(Encoding::ISO_8859_1) }
  let(:root_comment) { 'i am the root user'.force_encoding(Encoding::ISO_8859_1) }
  let(:user_struct_iso_8859_1) { Etc::Passwd.new(root, x, 0, 0, root_comment) }
  let(:group_struct_iso_8859_1) { Etc::Group.new(bin, x, 1, [root, bin, daemon]) }

  # http://www.fileformat.info/info/unicode/char/5e0c/index.htm
  # 希 Han Character 'rare; hope, expect, strive for'
  # In EUC_KR: \xfd \xf1 - 253 241
  # Likely to be read in as BINARY by Ruby unless system encoding is EUC_KR
  let(:euc_kr) { [253, 241].pack('C*').force_encoding(Encoding::EUC_KR)}
  let(:euc_kr_as_binary) { [253, 241].pack('C*') }
  # transcoded to UTF-8: \u5e0c - \xe5 \xb8 \x8c - 229 184 140
  let(:euc_kr_to_utf_8) { "\u5e0c" }

  # characters representing different UTF-8 widths
  # 1-byte A
  # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
  # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
  # 4-byte 𠜎 - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
  #
  # If system encoding is not UTF-8, these will likely be read in as BINARY by Ruby
  let(:mixed_utf_8) { "A\u06FF\u16A0\u{2070E}".force_encoding(Encoding::UTF_8) } # Aۿᚠ𠜎
  let(:mixed_utf_8_as_binary) { "A\u06FF\u16A0\u{2070E}".force_encoding(Encoding::BINARY) }

  describe "getgrent" do
    context "given an original system Etc Group struct with ISO-8850-1 string values" do
      before { Etc.expects(:getgrent).returns(group_struct_iso_8859_1) }
      let(:converted) { Puppet::Etc.getgrent }

      it "should return a struct with :name and :passwd field values converted to UTF-8" do
        [converted.name, converted.passwd].each do |value|
          expect(value.encoding).to eq(Encoding::UTF_8)
        end
      end

      it "should return a struct with a :mem array with all field values converted to UTF-8" do
        converted.mem.each { |elem| expect(elem.encoding).to eq(Encoding::UTF_8) }
      end
    end

    context "when Encoding.default_external is UTF-8" do
      original_encoding = Encoding.default_external

      before(:each) do
        Encoding.default_external = Encoding::UTF_8
      end

      after(:each) do
        Encoding.default_external = original_encoding
      end

      let(:group) { Etc::Group.new }

      before do
        # In a UTF-8 environment, the UTF-8 values will come back as UTF-8,
        # while the EUC_KR values will come back as binary So to simulate, group
        # membership contains a string with valid UTF-8 bytes in UTF-8 encoding,
        # and EUC_KR bytes in binary. We don't have any direction what to do
        # with bytes that aren't valid UTF-8 when the system is in UTF-8 - so we
        # leave them alone.
        group.mem = [mixed_utf_8, euc_kr_as_binary]
        # group name contains same EUC_KR bytes in binary
        group.name = euc_kr_as_binary
        # group passwd field is valid UTF-8
        group.passwd = mixed_utf_8
        Etc.expects(:getgrent).returns(group)
      end

      let(:converted) { Puppet::Etc.getgrent }

      it "should leave the valid UTF-8 in arrays unmodified" do
        expect(converted.mem[0]).to eq(mixed_utf_8)
        expect(converted.mem[0].encoding).to eq(Encoding::UTF_8) # just being explicit
      end

      it "should leave the valid UTF-8 values unmodified" do
        expect(converted.passwd).to eq(mixed_utf_8)
        expect(converted.passwd.encoding).to eq(Encoding::UTF_8) # just being explicit
      end

      it "should leave the EUC_KR binary-encoded values unmodified" do
        expect(converted.name).to eq(euc_kr_as_binary)
        expect(converted.name.encoding).to eq(Encoding::BINARY) # just being explicit
      end

      it "should leave EUC_KR binary-encoded values in arrays unmodifed" do
        expect(converted.mem[1]).to eq(euc_kr_as_binary)
        expect(converted.mem[1].encoding).to eq(Encoding::BINARY) # just being explicit
      end
    end

    context "when Encoding.default_external is NOT UTF-8" do
      original_encoding = Encoding.default_external

      before(:each) do
        Encoding.default_external = Encoding::EUC_KR
      end

      after(:each) do
        Encoding.default_external = original_encoding
      end

      let(:group) { Etc::Group.new }

      before do
        # In a non-UTF-8 environment, situation is reversed. The UTF-8 values
        # will come back as binary while the EUC_KR values will come back as
        # EUC_KR. So to simulate, group membership contains a string with valid
        # UTF-8 bytes in binary encoding, and EUC_KR bytes in EUC_KR. In this
        # case, we would "override" (set external encoding) on the UTF-8 binary
        # values, and "convert" (transcode) the EUC_KR values.
        group.mem = [mixed_utf_8_as_binary, euc_kr]
        # group name contains same EUC_KR bytes
        group.name = euc_kr
        # group passwd field is valid UTF-8 as binary
        group.passwd = mixed_utf_8_as_binary
        Etc.expects(:getgrent).returns(group)
      end

      let(:converted) { Puppet::Etc.getgrent }

      it "should override the encoding of valid UTF-8 binary-encoded values in arrays to UTF-8" do
        expect(converted.mem[0]).to eq(mixed_utf_8)
        expect(converted.mem[0].encoding).to eq(Encoding::UTF_8) # just being explicit
      end

      it "should override the encoding of valid UTF-8 binary-encoded values to UTF-8" do
        expect(converted.passwd).to eq(mixed_utf_8)
        expect(converted.passwd.encoding).to eq(Encoding::UTF_8) # just being explicit
      end

      it "should convert the EUC_KR values in arrays to UTF-8" do
        expect(converted.mem[1]).to eq(euc_kr_to_utf_8)
        expect(converted.mem[1].encoding).to eq(Encoding::UTF_8)
      end
      
      it "should convert the EUC_KR (non-UTF-8) values to UTF-8" do
        expect(converted.name).to eq(euc_kr_to_utf_8)
        expect(converted.name.encoding).to eq(Encoding::UTF_8)
      end
    end
  end

  describe "endgrent" do
    it "should call Etc.getgrent" do
      Etc.expects(:getgrent)
      Puppet::Etc.getgrent
    end
  end

  describe "setgrent" do
    it "should call Etc.setgrent" do
      Etc.expects(:setgrent)
      Puppet::Etc.setgrent
    end
  end

  describe "getpwent" do
    context "given an original system Etc Passwd struct with ISO-8859-1 string values" do
      before { Etc.expects(:getpwent).returns(user_struct_iso_8859_1) }
      let(:converted) { Puppet::Etc.getpwent }

      it "should return an Etc Passwd struct with field values converted to UTF-8" do
        [converted.name, converted.passwd, converted.gecos].each do |value|
          expect(value.encoding).to eq(Encoding::UTF_8)
        end
      end
    end

    context "given an original Etc::Passwd struct with a mix of UTF-8 and binary values" do
      let(:user) { Etc::Passwd.new }
      before do
        # user comment field is EUC_KR which would be read in as binary when
        # external encoding is UTF-8
        user.gecos =  euc_kr_as_binary
        # user passwd field is valid UTF-8
        user.passwd = mixed_utf_8

        Etc.expects(:getpwent).returns(user)
      end

      let(:converted) { Puppet::Etc.getpwent }

      it "should leave the binary values unmodified" do
        expect(converted.gecos).to eq(euc_kr_as_binary)
        expect(converted.gecos.encoding).to eq(Encoding::BINARY) # just being explicit
      end

      it "should leave the valid UTF-8 values unmodified" do
        expect(converted.passwd).to eq(mixed_utf_8)
        expect(converted.passwd.encoding).to eq(Encoding::UTF_8) # just being explicit
      end
    end
  end

  describe "endpwent" do
    it "should call Etc.endpwent" do
      Etc.expects(:endpwent)
      Puppet::Etc.endpwent
    end
  end

  describe "setpwent" do
    it "should call Etc.setpwent" do
      Etc.expects(:setpwent)
      Puppet::Etc.setpwent
    end
  end

  describe "getpwnam" do
    context "given a username to query" do
      it "should call Etc.getpwnam with that username" do
        Etc.expects(:getpwnam).with('foo')
        Puppet::Etc.getpwnam('foo')
      end
    end

    context "given an original system Etc Passwd struct with ISO-8859-1 string values" do
      it "should return an Etc Passwd struct with field values converted to UTF-8" do
        Etc.expects(:getpwnam).with('root').returns(user_struct_iso_8859_1)
        converted = Puppet::Etc.getpwnam('root')
        [converted.name, converted.passwd, converted.gecos].each do |value|
          expect(value.encoding).to eq(Encoding::UTF_8)
        end
      end
    end
  end

  describe "getgrnam" do
    context "given a group name to query" do
      it "should call Etc.getgrnam with that group name" do
        Etc.expects(:getgrnam).with('foo')
        Puppet::Etc.getgrnam('foo')
      end
    end

    context "given an original system Etc Group struct with ISO-8859-1 string values" do
      it "should return an Etc Group struct with field values converted to UTF-8" do
        Etc.expects(:getgrnam).with('bin').returns(group_struct_iso_8859_1)
        converted = Puppet::Etc.getgrnam('bin')
        [converted.name, converted.passwd].each do |value|
          expect(value.encoding).to eq(Encoding::UTF_8)
        end
        converted.mem.each { |elem| expect(elem.encoding).to eq(Encoding::UTF_8) }
      end
    end
  end

  describe "getgrgid" do
    context "given a group ID to query" do
      it "should call Etc.getgrgid with the id" do
        Etc.expects(:getgrgid).with(0)
        Puppet::Etc.getgrgid(0)
      end
    end

    context "given an original Etc Group struct with field values in ISO-8859-1" do
      it "should return an Etc Group struct with field values converted to UTF-8" do
        Etc.expects(:getgrgid).with(1).returns(group_struct_iso_8859_1)
        converted = Puppet::Etc.getgrgid(1)
        [converted.name, converted.passwd].each do |value|
          expect(value.encoding).to eq(Encoding::UTF_8)
        end
        converted.mem.each { |elem| expect(elem.encoding).to eq(Encoding::UTF_8) }
      end
    end
  end

  describe "getpwid" do
    context "given a UID to query" do
      it "should call Etc.getpwuid with the id" do
        Etc.expects(:getpwuid).with(2)
        Puppet::Etc.getpwuid(2)
      end
    end
  end

  context "given an orginal Etc Passwd struct with field values in ISO-8859-1" do
    it "should return an Etc Passwd struct with field values converted to UTF-8" do
      Etc.expects(:getpwuid).with(0).returns(user_struct_iso_8859_1)
      converted = Puppet::Etc.getpwuid(0)
      [converted.name, converted.passwd, converted.gecos].each do |value|
        expect(value.encoding).to eq(Encoding::UTF_8)
      end
    end
  end


end
