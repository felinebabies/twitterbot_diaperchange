# coding: utf-8
require 'logger'

require_relative '../stsbase'
require_relative '../bottwitterclient'

describe StsBase do
  before do
    #loggerの設定
    @logger = Logger.new(STDERR)
    @logger.level = Logger::WARN
  end

  subject { StsBase.new(@logger) }

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
      @wordsfile = File.join( root_dir, 'wordfile.yml')
    end

    after do
      unless @tweetid == nil then
        sleep(5)
        createclient.destroy_status(@tweetid)
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

  it 'get new mentions with empty argument and sould return nil' do
    sts = {}

    expect(subject.getnewmentions(sts)).to eq nil
  end

  it 'get new mentions with valid argument and sould return not nil' do
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

end
