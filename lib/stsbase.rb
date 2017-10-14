# coding: utf-8
require 'logger'

require_relative 'utils'
require_relative 'bottwitterclient'
require_relative 'replace'
require_relative 'changecommands'

module DiaperChangeBot
  class StsBase
    attr_reader :logger
    attr_accessor :userDataFilePath

    # 尿意の最大増加値
    MAXINCREASEVAL = 10

    # がまんの閾値
    ENDURANCEBORDER = 280

    # お漏らしの閾値
    LEAKBORDER = 330
    # 初期化
    def initialize(userDataFilePath, logger = nil)
      @modename = "fine"

      @userDataFilePath = userDataFilePath

      #loggerの設定
      @logger = logger || Logger.new(STDERR)
    end

    #loggerの設定
    def setlogger(logger = nil)
      #loggerの設定
      @logger = logger
    end

    # 尿意増加
    # 成功なら現在のvolumeを返す
    # 失敗ならnilを返す
    def increase(status)
      if status.has_key?('volume') then
        increaseval = (rand(MAXINCREASEVAL) + 1)
        @logger.info("Increase value: #{increaseval}")
        status["volume"] = status["volume"] + increaseval
        return status["volume"]
      else
        @logger.warn('Argument has not key \'volume\'')
        return nil
      end
    end

    # 喋る
    # 成功ならtweetのidを返す
    # 失敗ならnilを返す
    def speak(words)
      unless words.has_key?('autonomous') then
        @logger.error('argument words has not key \'autonomous\'')
        return nil
      end
      unless words['autonomous'].has_key?(@modename) then
        @logger.error('argument[\'autonomous\'] words has not key \'modename\'')
        return nil
      end
      word = words['autonomous'][@modename].sample

      # 文字列の置き換えを行う
      word = DiaperChangeBot::replacespecialmessage(word, nil, 140, @userDataFilePath, @logger)

      # ログにしゃべった内容を記録
      @logger.info("Random talk: #{word}")
      DiaperChangeBot::debugprint("Random talk: #{word}")

      # tweetする
      client = DiaperChangeBot::createclient
      begin
        tweet = client.update(word)
      rescue => e
        @logger.error("Tweet update failed: [#{e}]")
        return nil
      end

      return tweet.id
    end

    # 自分あての新しいメンションを取得する
    def getnewmentions(sts)
      unless sts.has_key?('lastmentiontime') then
        @logger.error('argument sts has not key \'lastmentiontime\'')
        return nil
      end
      client = DiaperChangeBot::createclient

      begin
        mentions = client.mentions()
        newlist = mentions.select do |tweet|
          tweet.created_at > sts["lastmentiontime"]
        end
      rescue
        @logger.warn("Failed to get mentions")
        mentions = []
        newlist = []
      end

      # 時刻順にソートする
      newlist.sort! do |a, b|
        a.created_at <=> b.created_at
      end
      mentions.sort! do |a, b|
        a.created_at <=> b.created_at
      end

      # メンションをログに記録する
      newlist.each do |mention|
        @logger.info("mention: #{mention.created_at}: #{mention.text}")
      end

      if ! mentions.empty? then
        sts["newestmention"] = mentions.last.created_at
      end

      return newlist
    end

    # メンション取得時刻を更新する
    def updatelastmentiontime(sts)
      if sts.has_key?("newestmention") then
        sts["lastmentiontime"] = sts["newestmention"]
      else
        sts["lastmentiontime"] = Time.now
      end
    end

    # 回答セットから応答を抜き出す
    def getanswerstr(mention, answerset, maxlen)
      answerobj = answerset.select do |answerpair|
        pairs = answerpair["words"].select do |word|
          mention.text.include?(word)
        end

        ! pairs.empty?
      end

      if answerobj.empty? then
        # デフォルトメッセージから選ぶ
        answertext = answerset.last["answers"].sample
      else
        # 言葉に合わせて応答を選ぶ
        answertext = answerobj.first["answers"].sample
      end

      # 文字列の置き換えを行う
      answertext = DiaperChangeBot::replacespecialmessage(answertext, mention, maxlen, @userDataFilePath, @logger)

      return answertext
    end

    # 呼びかけに反応する
    def answertomentions(words, sts, mentions)
      client = DiaperChangeBot::createclient
      answerset = words["answerset"][@modename]

      mentions.each do |mention|
        useridstr = "@" + mention.user.screen_name + " "
        maxlen = 140 - useridstr.size
        answerstr = getanswerstr(mention, answerset, maxlen)

        tweetstr = useridstr + answerstr

        DiaperChangeBot::debugprint("maxlen=#{maxlen}")
        DiaperChangeBot::debugprint("answerstrlen=#{answerstr.size}")

        # ログにしゃべった内容を記録
        @logger.info("Answer to mention: #{tweetstr}")

        # ツイートする
        client.update(tweetstr, :in_reply_to_status_id => mention.id)

      end
    end

    # 呼びかけに反応する
    def answer(words, sts)
      mentions = getnewmentions(sts)
      answertomentions(words, sts, mentions)
    end

    # 文字列におむつ交換コマンドが含まれていたらtrueを返す
    def includechange?(str)
      changeset = ChangeCommands.instance.commands.select do |pattern|
        str.include?(pattern)
      end
      return ! changeset.empty?
    end

    # おむつ交換の御礼を言う
    def saythanks(mention, words, islate = false)
      client = DiaperChangeBot::createclient

      objuser = client.user(mention.user.id)

      if islate then
        wordset = words["changeset"]["late"]
      else
        wordset = words["changeset"]["thanks"]
      end

      answerstr = wordset.sample

      # ツイートする
      tweetstr = "@" + objuser.screen_name + " " + answerstr
      client.update(tweetstr, :in_reply_to_status_id => mention.id)

      # ログにしゃべった内容を記録
      @logger.info("Thanks to diaper change: #{tweetstr}")

      # コンソールにしゃべった内容を表示
      DiaperChangeBot::debugprint(tweetstr)
    end

    # おむつ交換判定を行う
    def diaperchangecheck(sts, words, mentions)
      delmentions = []

      mentions.each do |mention|
        # 取得したメンションにおむつ交換コマンドが含まれるかチェック
        if includechange?(mention.text) then
          # まだおむつが濡れていれば交換処理
          if sts["wetsts"].diaperwet? then
            # 御礼
            saythanks(mention, words)

            # 替えてくれた人にポイントをつける
            manager = UserManager.new(@userDataFilePath, @logger)
            manager.addchangepoint(mention.user.id, 1)
            manager.save

            # 状態を変更する
            sts["wetsts"] = StsChanging.new(@userDataFilePath, @logger)

          else
            # 濡れていなければ御礼だけ言う
            saythanks(mention, words, true)
          end

          delmentions << mention.id
        end
      end

      # メンション配列から、返信済みのものを削除する
      mentions.delete_if do |mention|
        delmentions.include?(mention.id)
      end
    end

    # 就寝起床処理
    def checksleep(sts)
      if DEBUG_NO_SLEEP then
        #寝ていたら起きる
        if sts["wetsts"].sleeping? then
          sts["wetsts"] = StsWakeup.new(@userDataFilePath, @logger)
        end

        #起きていれば何もしない
        return
      end

      # その日の起床・睡眠時刻を設定
      if sts["wakeuptime"].to_date < Date.today || sts["gotobedtime"].to_date < Date.today then
        day = Time.now

        # 起床はランダムな8時台
        sts["wakeuptime"] = Time.local(day.year, day.month, day.day, 8, rand(60),0)

        # 就寝はランダムな21時台
        sts["gotobedtime"] = Time.local(day.year, day.month, day.day, 21, rand(60),0)
      end

      # 時刻に従った状態変更
      if (Time.now > sts["gotobedtime"]) && (! sts["wetsts"].sleeping?) then
        # 寝る
        sts["wetsts"] = StsGotoSleep.new(@userDataFilePath, @logger)
        return
      end

      if (Time.now < sts["wakeuptime"]) && (! sts["wetsts"].sleeping?) then
        # 寝る
        sts["wetsts"] = StsGotoSleep.new(@userDataFilePath, @logger)
        return
      end

      if (Time.now > sts["gotobedtime"]) && sts["wetsts"].sleeping? then
        # 継続して寝る
        return
      end

      if (Time.now < sts["wakeuptime"]) && sts["wetsts"].sleeping? then
        # 継続して寝る
        return
      end

      if (Time.now > sts["wakeuptime"]) && sts["wetsts"].sleeping? then
        # 起きる
        sts["wetsts"] = StsWakeup.new(@userDataFilePath, @logger)
        return
      end
    end

    # 行動セット呼び出し
    def process(words, sts, userDataPath)
      # 尿意増加
      increase(sts)

      # 呼びかけに応答

      # 状態変更

      # 自発的発言
      speak(words)
    end

    # 自身のクラス名を返す
    def name()
      return self.class.to_s
    end

    # おむつが濡れているかを返す
    def diaperwet?()
      return false
    end

    # 寝ているかを返す
    def sleeping?()
      return false
    end
  end
end
