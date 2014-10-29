# coding: utf-8

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
    end

    context 'saving' do
      subject do
        @usermanager.adduser(0)
        @usermanager
      end

      it 'should save to usermanagertest01.yml and file exists' do
        subject.save
        expect(File.exists?(@yml_file)).to eq true
      end
    end

  end

end
