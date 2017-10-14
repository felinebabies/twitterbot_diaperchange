# coding: utf-8

require_relative 'utils'
require_relative 'stsbase'

module DiaperChangeBot
  # おむつが乾いた状態
  class StsFine < StsBase
    # 初期化
    def initialize(userDataFilePath, logger = nil)
      super userDataFilePath, logger
      @modename = "fine"
    end

    def process(words, sts)
      # 尿意増加
      increase(sts)

      # 呼びかけに反応する
      answer(words, sts)
      updatelastmentiontime(sts)

      # 確率で自発的発言
      if DiaperChangeBot::talkrand() then
        sts["wetsts"].speak(words)
      end

      # 状態変更
      if(sts["volume"] >= ENDURANCEBORDER) then
        # 尿意が一定以上ならがまん状態にする
        sts["wetsts"] = StsEndurance.new(@userDataFilePath, @logger)

        # 状態変更時は強制発言
        sts["wetsts"].speak(words)
      else
        # 変更が無ければ睡眠判定
        checksleep(sts)
      end
    end
  end

  # がまん状態
  class StsEndurance < StsBase
    # 初期化
    def initialize(userDataFilePath, logger = nil)
      super userDataFilePath, logger
      @modename = "endurance"
    end

    def process(words, sts)
      # 尿意増加
      increase(sts)

      # 呼びかけに反応する
      answer(words, sts)
      updatelastmentiontime(sts)

      # 確率で自発的発言
      if DiaperChangeBot::talkrand() then
        sts["wetsts"].speak(words)
      end

      # 状態変更
      if(sts["volume"] >= LEAKBORDER) then
        # 尿意が一定以上ならお漏らし状態にする
        sts["wetsts"] = StsLeak.new(@userDataFilePath, @logger)

        @logger.info('Status changed to Leak')
      else
        # 変更が無ければ睡眠判定
        checksleep(sts)
      end
    end
  end

  # お漏らし状態
  class StsLeak < StsBase
    # 初期化
    def initialize(userDataFilePath, logger = nil)
      super userDataFilePath, logger
      @modename = "leak"
    end

    def process(words, sts)
      # 漏らした時刻を更新する
      sts["leaktime"] = Time.now

      # 尿意をリセットする
      sts["volume"] = 0

      # 呼びかけに反応する
      answer(words, sts)
      updatelastmentiontime(sts)

      # 自発的発言
      sts["wetsts"].speak(words)

      # 状態変更
      sts["wetsts"] = StsWet.new(@userDataFilePath, @logger)

      @logger.info('Status changed to Wet')
    end
  end

  # 濡れた状態
  class StsWet < StsBase
    # 初期化
    def initialize(userDataFilePath, logger = nil)
      super userDataFilePath, logger
      @modename = "wet"
    end

    def process(words, sts)
      # メンション取得
      mentions = getnewmentions(sts)

      # おむつ交換判定
      diaperchangecheck(sts, words, mentions)

      # 呼びかけに反応する
      answertomentions(words, sts, mentions)
      updatelastmentiontime(sts)

      # おむつを交換済みなら処理を終了する
      if ! diaperwet? then
        return
      end

      # 尿意増加
      increase(sts)

      # 確率で自発的発言
      if DiaperChangeBot::talkrand() then
        sts["wetsts"].speak(words)
      end

      # 状態変更
      if(sts["volume"] >= LEAKBORDER) then
        # 尿意が一定以上ならお漏らし状態にする
        sts["wetsts"] = StsLeak.new(@userDataFilePath, @logger)

        @logger.info('Status changed to Leak')
      else
        # 変更が無ければ睡眠判定
        checksleep(sts)
      end
    end

    # おむつが濡れているかを返す
    def diaperwet?()
      return true
    end
  end

  # おむつ交換中状態
  class StsChanging < StsBase
    # 初期化
    def initialize(userDataFilePath, logger = nil)
      super userDataFilePath, logger
      @modename = "changing"
    end

    def process(words, sts)
      # 尿意増加
      increase(sts)

      # 呼びかけに反応する
      answer(words, sts)
      updatelastmentiontime(sts)

      # 自発的発言
      sts["wetsts"].speak(words)

      # 状態変更
      sts["wetsts"] = StsFine.new(@userDataFilePath, @logger)

      @logger.info('Status changed to Fine')
    end
  end

  # 寝入り状態
  class StsGotoSleep < StsBase
    # 初期化
    def initialize(userDataFilePath, logger = nil)
      super userDataFilePath, logger
      @modename = "gotosleep"
    end

    def process(words, sts)
      # 自発的発言
      sts["wetsts"].speak(words)

      # 状態変更
      sts["wetsts"] = StsSleeping.new(@userDataFilePath, @logger)

      @logger.info('Status changed to Sleeping')
    end

    # 寝ているかを返す
    def sleeping?()
      return true
    end
  end

  # 睡眠中状態
  class StsSleeping < StsBase
    # 初期化
    def initialize(userDataFilePath, logger = nil)
      super userDataFilePath, logger
      @modename = "sleeping"
    end

    def process(words, sts)
      # 確率で自発的発言
      if DiaperChangeBot::talkrand() then
        sts["wetsts"].speak(words)
      end

      # 呼びかけに反応する
      answer(words, sts)
      updatelastmentiontime(sts)

      # 睡眠判定
      checksleep(sts)
    end

    # 寝ているかを返す
    def sleeping?()
      return true
    end
  end

  # 目覚め状態
  class StsWakeup < StsBase
    # 初期化
    def initialize(userDataFilePath, logger = nil)
      super userDataFilePath, logger
      @modename = "wakeup"
    end

    def process(words, sts)
      # 漏らした時刻を更新する
      sts["leaktime"] = Time.now

      # 尿意をリセットする
      sts["volume"] = 0

      # 呼びかけに反応する
      answer(words, sts)
      updatelastmentiontime(sts)

      # 自発的発言
      sts["wetsts"].speak(words)

      # 状態変更
      # 必ずおねしょする
      sts["wetsts"] = StsWet.new(@userDataFilePath, @logger)

      @logger.info('Wakeup and status changed to Wet')
    end

    # 寝ているかを返す
    def sleeping?()
      return true
    end
  end
end
