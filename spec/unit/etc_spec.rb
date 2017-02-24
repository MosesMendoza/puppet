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
    before { Etc.expects(:getpwent).returns(user_struct_iso_8859_1) }
    let(:converted) { Puppet::Etc.getpwent }
    context "given an original system Etc Passwd struct with ISO-8859-1 string values" do
      it "should return an Etc Passwd struct with field values converted to UTF-8" do
        [converted.name, converted.passwd, converted.gecos].each do |value|
          expect(value.encoding).to eq(Encoding::UTF_8)
        end
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
