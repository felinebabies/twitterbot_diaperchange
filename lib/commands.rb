# coding: utf-8
# サブコマンド設定
require 'bundler'
Bundler.require

require_relative 'utils'

module DiaperChangeBot
  class Commands < Thor
    option :force, :type => :boolean, :aliases => "-f", :desc => "強制的につぶやかせる"
    desc "exec", "botの通常動作を一回分起動する"
    def exec
      # 設定ファイル名指定
      savefile = File.join($savedir, "botsave.yml")
      wordsfile = File.join($savedir, "wordfile.yml")

      # 必ずつぶやくモード
      if(options[:force]) then
        DiaperChangeBot::debugprint("必ずつぶやくモードを設定しました。")
        $always_tweet_flag = true
      end

      # loggerのインスタンスを作成
      logger = Logger.new('log/botlog.log', 0, 5 * 1024 * 1024)
      logger.level = Logger::INFO

      logger.info("Bot script start")

      begin
        # botのインスタンス生成
        botobj = Bot.new(savefile, wordsfile, logger)

        # bot処理実行
        botobj.process

        # 現状をコンソールに出力
        DiaperChangeBot::debugprint("現在の尿意：" + botobj.volume.to_s)
        DiaperChangeBot::debugprint("現在の状態：" + botobj.wetsts)

        logger.info("Current volume: #{botobj.volume.to_s}")
        logger.info("Current status: #{botobj.wetsts}")

        # 状態をセーブ
        botobj.save(savefile)
      rescue => ex
        logger.error("Inner error: #{ex.message}")
        logger.error("Back trace: #{ex.backtrace}")
        pp ex.backtrace
      end

      logger.info("Bot script finish")
    end

    desc "showchangeword", "おむつ交換用キーワードの一覧を表示する"
    def showchangeword
      keywordlist = ChangeCommands.instance.commands
      puts keywordlist
    end

    desc "ranking", "おむつ交換してくれた人の一覧を表示する"
    def ranking
      userdatafile = File.join($savedir, 'userdata.yml')
      logger = Logger.new('log/botlog.log', 0, 5 * 1024 * 1024)
      logger.level = Logger::INFO

      logger.info("Bot script:ranking start")

      manager = UserManager.new(userdatafile, logger)

      userranking = manager.userdata.sort do |a,b|
        b["diaperchangepoint"] <=> a["diaperchangepoint"]
      end

      userranking.each do |item|
        puts "displayname:#{item["displayname"]} score:#{item["diaperchangepoint"]}"
      end
      logger.info("output #{manager.userdata.count} users")

      logger.info("Bot script:ranking finish")
    end
  end
end
