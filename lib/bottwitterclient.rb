# coding: utf-8
# シングルトンのtwitterクライアントクラス
require 'bundler'
require 'yaml'
require 'singleton'
Bundler.require

class BotTwitterClient
  include Singleton

  attr_accessor :client
  def initialize
    settingfile = File.expand_path(File.dirname(__FILE__)) + "/../savedata/tsettings.yml"
    tsettings = YAML.load_file(settingfile)

    @client = Twitter::REST::Client.new do |config|
      config.consumer_key        = tsettings["consumer_key"]
      config.consumer_secret     = tsettings["consumer_secret"]
      config.access_token        = tsettings["access_token"]
      config.access_token_secret = tsettings["access_token_secret"]
    end
  end
end

# twitterクライアントを生成する
def createclient()
  twitterclient = BotTwitterClient.instance

  return twitterclient.client
end
