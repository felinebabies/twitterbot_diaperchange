# coding: utf-8
require 'logger'

require_relative '../lib/stsbase'
require_relative '../lib/bottwitterclient'

describe DiaperChangeBot::StsBase do
  before do
    #loggerの設定
    @logger = Logger.new(STDERR)
    @logger.level = Logger::WARN

    #ユーザ情報ファイルのパス
    tmpdirpath = File.join( File.dirname(__FILE__), 'tmp')
    @userDataFilePath = File.join( tmpdirpath, 'userdata.yml')
  end

  subject { DiaperChangeBot::StsBase.new(@userDataFilePath, @logger) }

  it 'increase with invalid argument and sould return nil' do
    status = {}

    expect(subject.increase(status)).to eq nil
  end

  it 'increase and status[\'volume\'] sould return be not 0' do
    status = {
      'volume' => 0
    }

    expect(subject.increase(status)).not_to eq 0
  end

  context 'update message in twitter' do
    before do
      @tweetid = nil
      root_dir = File.join( File.dirname(__FILE__), '..')
      @wordsfile = File.join( root_dir, '/savedata/wordfile.yml')
    end

    after do
      unless @tweetid == nil then
        sleep(5)
        DiaperChangeBot::createclient.destroy_status(@tweetid)
      end
    end

    it 'speak with empty argument and should return be nil' do
      words = {}
      tweetid = subject.speak(words)

      expect(tweetid).to eq nil
    end

    it 'speak and should return be not nil' do
      expect(File.exists?(@wordsfile)).to eq true

      words = YAML.load_file(@wordsfile)
      @tweetid = subject.speak(words)

      expect(@tweetid).not_to eq nil
    end
  end

  it 'get new mentions with empty argument and should return nil' do
    sts = {}

    expect(subject.getnewmentions(sts)).to eq nil
  end

  it 'get new mentions with valid argument and should return not nil' do
    sts = {
      "volume" => 0,
      "wetsts" => nil,
      "leaktime" => Time.now,
      "lastmentiontime" => Time.now - (60 * 60 * 24),
      "wakeuptime" => Time.now - (60 * 60 * 24),
      "gotobedtime" => Time.now - (60 * 60 * 24)
    }

    expect(subject.getnewmentions(sts)).not_to eq nil
  end

  it 'update get last mentions time without newestmention and should time updated' do
    sts = {
      "volume" => 0,
      "wetsts" => nil,
      "leaktime" => Time.now,
      "lastmentiontime" => Time.now - (60 * 60 * 24),
      "wakeuptime" => Time.now - (60 * 60 * 24),
      "gotobedtime" => Time.now - (60 * 60 * 24)
    }

    oldtime = sts['lastmentiontime']

    subject.updatelastmentiontime(sts)

    expect(sts['lastmentiontime']).to be > oldtime
  end

  it 'update get last mentions time with newestmention and should time updated' do
    sts = {
      "volume" => 0,
      "wetsts" => nil,
      "leaktime" => Time.now,
      "lastmentiontime" => Time.now - (60 * 60 * 24),
      "wakeuptime" => Time.now - (60 * 60 * 24),
      "gotobedtime" => Time.now - (60 * 60 * 24),
      "newestmention" => Time.now
    }

    subject.updatelastmentiontime(sts)

    expect(sts['lastmentiontime']).to eq sts["newestmention"]
  end

end
