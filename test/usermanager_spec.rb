﻿# coding: utf-8

require_relative '../usermanager'

describe UserManager do
  before do
    @tmp_dir = File.join( File.dirname(__FILE__), 'tmp')
    FileUtils.mkdir(@tmp_dir)  if !File.exists?(@tmp_dir)
    @yml_file = File.join(@tmp_dir, 'usermanagertest01.yml')
  end

  after do
    FileUtils.rm(@yml_file)  if File.exists?(@yml_file)
  end

  context 'with new filename "usermanagertest01.yml"' do
    before { @usermanager = UserManager.new(@yml_file) }
    subject { @usermanager }

    it 'does not exists "usermanagertest01.yml"' do
      expect(File.exist?('usermanagertest01.yml')).to eq false
    end

    it 'userdata to be empty' do
      expect(subject.userdata).to be_empty
    end

    context 'add empty user data' do
      subject do
        @usermanager.adduser(0)
        @usermanager
      end

      it 'userdata to be not empty' do
        expect(subject.userdata).not_to be_empty
      end

      it 'get userdata by valid id to be not nil' do
        expect(subject.getuser(0)).not_to be_nil
      end

      it 'get userdata by invalid id to be nil' do
        expect(subject.getuser(-9999)).to be_nil
      end

      context 'update userdata' do
        subject do
          @usermanager
        end

        it 'update by valid id to be true' do
          userobj = {
            "id" => 0,
            "diaperchangepoint" => 1,
            "calledname" => "",
            "interestpoint" => 0,
            "displayname" => ""
          }
          expect(subject.update(userobj)).to eq true
        end
      end
    end

    context 'saving' do
      subject do
        @usermanager.adduser(0)
        @usermanager
      end

      it 'should save to yaml and load from yaml' do
        subject.save
        expect(File.exists?(@yml_file)).to eq true
	@yml_file2 = UserManager.new(@yml_file)
	expect(@yml_file2.userdata).not_to be_empty
      end
    end

  end

end
