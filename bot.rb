# coding: utf-8
# おむつ交換Bot
require 'bundler'
Bundler.require

require 'pp'

require_relative 'lib/utils'
require_relative 'lib/globals'
require_relative 'lib/bottwitterclient'
require_relative 'lib/usermanager'
require_relative 'lib/replace'
require_relative 'lib/status'
require_relative 'lib/commands'
require_relative 'lib/changecommands'
require_relative 'lib/bot'

# 自身を実行した場合にのみ起動
if __FILE__ == $PROGRAM_NAME then
  DiaperChangeBot::Commands.start(ARGV)
end
