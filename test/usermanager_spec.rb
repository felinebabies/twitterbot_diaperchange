# coding: utf-8

require_relative '../usermanager'

describe UserManager do
  context 'with new filename "usermanagertest01.yml"' do
    before { @usermanager = UserManager.new('usermanagertest01.yml') }
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

  end

end
