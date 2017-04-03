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
  # Not convertible to UTF-8 without an intermediate encoding as a hint, likely
  # to be read in as BINARY by Ruby unless system is in EUC_KR
  let(:not_convertible) { [253, 241].pack('C*') }

  # characters representing different UTF-8 widths
  # 1-byte A
  # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
  # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
  # 4-byte 𠜎 - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
  #
  # Should all convert cleanly to UTF-8
  # Unless the system is in UTF-8, these will likely be read in as BINARY by Ruby
  let(:convertible_utf8) { "A\u06FF\u16A0\u{2070E}" } # Aۿᚠ𠜎
  let(:convertible_binary) { "A\u06FF\u16A0\u{2070E}".force_encoding(Encoding::BINARY) }

  # For the methods described which actually expect an encoding conversion, we
  # only superficially test via #force_encoding - the deeper level testing is in
  # character_encoding_spec.rb which handles testing transcoding etc.

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

    context "given an original Etc::Group struct with BINARY field values" do
      original_encoding = Encoding.default_external

      after(:each) do
        Encoding.default_external = original_encoding
      end

      let(:group) { Etc::Group.new }

      before do
        # group membership contains a string with valid UTF-8 bytes in binary
        # encoding and a string in binary that cannot be converted without an
        # intermediate non-UTF-8 encoding
        group.mem = [convertible_binary, not_convertible]
        # group name contains a binary value that cannot be converted without an
        # intermediate non-UTF-8 encoding
        group.name = not_convertible
        # group passwd field is valid UTF-8
        group.passwd = convertible_binary
        Etc.expects(:getgrent).returns(group)
      end

      context "when Encoding.default_external is UTF-8" do
        before(:each) do
          Encoding.default_external = Encoding::UTF_8
        end

        let(:converted) { Puppet::Etc.getgrent }

        it "should convert convertible values in arrays to UTF-8" do
          expect(converted.mem[0]).to eq("A\u06FF\u16A0\u{2070E}")
          expect(converted.mem[0].encoding).to eq(Encoding::UTF_8) # just being explicit
        end

        it "should leave the unconvertible binary values unmodified" do
          expect(converted.name).to eq([253, 241].pack('C*'))
          expect(converted.name.encoding).to eq(Encoding::BINARY) # just being explicit
        end

        it "should leave unconvertible binary values in arrays unmodifed" do
          expect(converted.mem[1]).to eq([253, 241].pack('C*'))
          expect(converted.mem[1].encoding).to eq(Encoding::BINARY) # just being explicit
        end

        it "should convert values that can be converted to UTf-8" do
          expect(converted.passwd).to eq("A\u06FF\u16A0\u{2070E}")
          expect(converted.passwd.encoding).to eq(Encoding::UTF_8) # just being explicit
        end
      end

      context "when Encoding.default_external is not UTF-8" do
        before(:each) do
          Encoding.default_external = Encoding::EUC_KR
        end

        let(:converted) { Puppet::Etc.getgrent }

        # http://www.fileformat.info/info/unicode/char/5e0c/index.htm
        # 希 Han Character 'rare; hope, expect, strive for'
        # In EUC_KR: \xfd \xf1 - 253 241
        # While not convertible to UTF-8 without an intermediate encoding as
        # a hint, if external encoding is EUC_KR but we receive this in
        # BINARY we should be able to convert it to UTF-8
        # In UTF-8: \u5e0c - \xe5 \xb8 \x8c - 229 184 140
        it "should convert binary values in arrays that can leverage Encoding.default_external for a transcoding hint" do
          expect(converted.mem[1]).to eq("\u5e0c")
          expect(converted.mem[1].encoding).to eq(Encoding::UTF_8)
        end

        it "should convert binary values that can leverage Encoding.default_external for a transcoding hint" do
          expect(converted.name).to eq("\u5e0c")
          expect(converted.name.encoding).to eq(Encoding::UTF_8)
        end

        # Just to confirm our known-good UTF-8 bytes are also converted
        it "should convert values already representing UTF-8 bytes to UTF-8" do
          expect(converted.passwd).to eq("A\u06FF\u16A0\u{2070E}")
          expect(converted.passwd.encoding).to eq(Encoding::UTF_8) # just being explicit
        end
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

    context "given an original Etc::Passwd struct with field values that cannot be converted to UTF-8" do
      let(:user) { Etc::Passwd.new }
      before do
        # user comment field cannot be converted to UTF-8
        user.gecos =  not_convertible
        # user passwd field is valid UTF-8
        user.passwd = convertible_binary

        Etc.expects(:getpwent).returns(user)
      end

      let(:converted) { Puppet::Etc.getpwent }

      it "should leave the unconvertible values unmodified" do
        expect(converted.gecos).to eq([253, 241].pack('C*'))
        expect(converted.gecos.encoding).to eq(Encoding::BINARY) # just being explicit
      end

      it "should convert values that can be converted to UTf-8" do
        expect(converted.passwd).to eq("A\u06FF\u16A0\u{2070E}")
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
