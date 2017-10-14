# coding: utf-8
# bot本体クラス
require 'bundler'
Bundler.require

module DiaperChangeBot
  class Bot
    # 尿意レベル
    def volume
      return @status["volume"]
    end

    # 尿状態の文字列を返す
    def wetsts
      return @status["wetsts"].name
    end

    def initialize(stsfile = nil, wordsfile = nil, logger = nil)
      #loggerの設定
      @logger = logger || Logger.new(STDERR)

      # 現在の状態を設定
      if stsfile == nil || !File.exist?(stsfile) then
        @status = {
          "volume" => 0,
          "wetsts" => StsFine.new(File.join($savedir, 'userdata.yml'), logger),
          "leaktime" => Time.now,
          "lastmentiontime" => Time.now,
          "wakeuptime" => Time.now - (60 * 60 * 24),
          "gotobedtime" => Time.now - (60 * 60 * 24)
        }

        @logger.debug('Creating default status object')
      else
        File.open(stsfile, "r") do |f|
          f.flock(File::LOCK_SH)
          @status = YAML.load(f.read)

          @logger.debug('Creating status object from file')

          #ユーザデータファイルのパスを再設定する
          @status["wetsts"].userDataFilePath = File.join($savedir, 'userdata.yml')
        end

        @status["wetsts"].setlogger(@logger)
      end

      # 応答パターン設定
      if wordsfile == nil || !File.exist?(wordsfile) then
        @words = {
          "autonomous" => {
          "fine" => [
          "まだ大丈夫。",
          "こんにちは。"
          ],
          "endurance" => [
          "うう、おしっこでそう……",
          "にゅーん……",
          "なんだかおちつかないー",
          "漏っちゃうー"
          ],
          "leak" => [
          "（しょろろろ……）あ、出ちゃった……"
          ],
          "wet" => [
          "うう、おむつがびしょびしょー"
          ],
          "changing" => [
          "新しいおむつ～♪"
          ],
          "gotosleep" => [
          "そろそろ寝る時間。おやすみ～"
          ],
          "sleeping" => [
          "すー……すー……"
          ],
          "wakeup" => [
          "おはよう～"
          ]
          },
          "answerset" => {
          "fine" => [
          {"words" => ["好き"] , "answers" => ["ぼくも好き！"]},
          {"words" => ["default"] , "answers" => ["にゃーん。"]}
          ],
          "endurance" => [
          {"words" => ["好き"] , "answers" => ["ぼくも好き！"]},
          {"words" => ["default"] , "answers" => ["にゃーん。"]}
          ],
          "leak" => [
          {"words" => ["好き"] , "answers" => ["ぼくも好き！"]},
          {"words" => ["default"] , "answers" => ["にゃーん。"]}
          ],
          "wet" => [
          {"words" => ["好き"] , "answers" => ["ぼくも好き！"]},
          {"words" => ["default"] , "answers" => ["にゃーん。"]}
          ],
          "changing" => [
          {"words" => ["好き"] , "answers" => ["ぼくも好き！"]},
          {"words" => ["default"] , "answers" => ["にゃーん。"]}
          ],
          "gotosleep" => [
          {"words" => ["好き"] , "answers" => ["ぼくも好き！"]},
          {"words" => ["default"] , "answers" => ["にゃーん。"]}
          ],
          "sleeping" => [
          {"words" => ["好き"] , "answers" => ["ぼくも好き！"]},
          {"words" => ["default"] , "answers" => ["にゃーん。"]}
          ],
          "wakeup" => [
          {"words" => ["好き"] , "answers" => ["ぼくも好き！"]},
          {"words" => ["default"] , "answers" => ["にゃーん。"]}
          ]
          },
          "changeset" => {
          "thanks" => [
          "わあ、おむつ替えありがとう！"
          ],
          "late" => [
          "ありがとうね、でももう交換してもらっちゃった。"
          ]
          }
        }
      else
        @words = YAML.load_file(wordsfile)
      end
    end

    # 応答パターン設定
    def setwords(words)
      @words = words
    end

    # セーブする。
    def save(stsfile)
      #logger のインスタンスはセーブしない
      loggerInstance = @status["wetsts"].logger
      @status["wetsts"].setlogger(nil)

      File.open(stsfile, File::RDWR|File::CREAT) do |yml|
        yml.flock(File::LOCK_EX)
        yml.rewind
        YAML.dump(@status, yml)
        yml.flush
        yml.truncate(yml.pos)
      end

      #loggerのインスタンスを戻す
      @status["wetsts"].setlogger(loggerInstance)
    end

    #一回分の活動
    def process()
      @status["wetsts"].process(@words, @status)
    end
  end
end
