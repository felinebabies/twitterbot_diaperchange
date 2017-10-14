# coding: utf-8
# おむつ交換Bot
require 'bundler'
Bundler.require

require 'pp'
require 'yaml'
require 'singleton'

require_relative 'lib/utils'
require_relative 'lib/globals'
require_relative 'lib/bottwitterclient'
require_relative 'lib/usermanager'
require_relative 'lib/replace'
require_relative 'lib/status'
require_relative 'lib/commands'
require_relative 'lib/bot'

# おむつ交換コマンド管理クラス
class ChangeCommands
  include Singleton

  attr_reader :commands
  def initialize
    @commands = YAML.load_file(File.join($savedir, "changecommands.yml"))
  end
end

# 自身を実行した場合にのみ起動
if __FILE__ == $PROGRAM_NAME then
  DiaperChangeBot::Commands.start(ARGV)
end
