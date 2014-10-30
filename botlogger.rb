# coding: utf-8
#ログ設定モジュール

require 'logger'

module BotLogger
  @log_dir = File.join( File.dirname(__FILE__), 'log')
  FileUtils.mkdir(@log_dir)  if !File.exists?(@log_dir)

  @log = Logger.new("log/botlog.txt", 100, 10 * 1024 * 1024)

  # FATAL, ERROR, WARN, INFO, DEBUG
  @log.level = Logger::INFO

  def self.log
    return @log
  end
end
