# coding: utf-8
# サブコマンド設定
require 'bundler'
Bundler.require

module DiaperChangeBot
  class Commands < Thor
    option :force, :type => :boolean
    desc "exec", "botの通常動作を一回分起動する"
    def exec
      # 設定ファイル名指定
      savefile = File.join($savedir, "botsave.yml")
      wordsfile = File.join($savedir, "wordfile.yml")

      # 必ずつぶやくモード
      if(options[:force]) then
        debugprint("必ずつぶやくモードを設定しました。")
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
        debugprint("現在の尿意：" + botobj.volume.to_s)
        debugprint("現在の状態：" + botobj.wetsts)

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
  end
end