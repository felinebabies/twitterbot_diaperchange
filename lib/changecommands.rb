# coding: utf-8
# おむつ交換キーワード一覧管理クラス
require 'bundler'
Bundler.require

require 'yaml'
require 'singleton'
require_relative 'utils'
require_relative 'globals'

module DiaperChangeBot
  class ChangeCommands
    include Singleton

    attr_reader :commands
    def initialize
      @commands = YAML.load_file(File.join($savedir, "changecommands.yml"))
    end
  end
end
