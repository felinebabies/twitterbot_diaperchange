# coding: utf-8
# おむつ交換Bot
require 'pp'
require 'yaml'
require 'optparse'
require 'singleton'

require_relative 'bottwitterclient'
require_relative 'usermanager'
require_relative 'replace'
require_relative 'status'

# 当スクリプトファイルの所在
$scriptdir = File.expand_path(File.dirname(__FILE__))

# 一日中寝ないモード
DEBUG_NO_SLEEP = false

# ランダムなつぶやきを必ず実行するフラグ
$always_tweet_flag = false

# デバッグ出力
def debugprint(str)
  #puts (str.encode("CP932"))
  puts(str)
end

# コマンドラインオプション解析
def cmdline
  args = {}

  OptionParser.new do |parser|
    parser.on('-f', '--f', '必ずつぶやく') {|v| args[:force] = v}
    parser.parse!(ARGV)
  end

  return args
end

# ランダムなつぶやきを行うかの乱数判定
def talkrand()
  if($always_tweet_flag == true) then
    return(true)
  else
    return(rand(20) == 0)
  end
end

# おむつ交換コマンド管理クラス
class ChangeCommands
  include Singleton

  attr_reader :commands
  def initialize
    @commands = YAML.load_file($scriptdir + "/changecommands.yml")
  end
end

class DiaperChangeBot
  # 尿意レベル
  def volume
    return @status["volume"]
  end

  # 尿状態の文字列を返す
  def wetsts
    return @status["wetsts"].name
  end

  def initialize(stsfile = nil, wordsfile = nil)
    # 現在の状態を設定
    if stsfile == nil || !File.exist?(stsfile) then
      @status = {
        "volume" => 0,
        "wetsts" => StsFine.new,
        "leaktime" => Time.now,
        "lastmentiontime" => Time.now,
        "wakeuptime" => Time.now - (60 * 60 * 24),
        "gotobedtime" => Time.now - (60 * 60 * 24)
      }
    else
      File.open(stsfile, "r") do |f|
        f.flock(File::LOCK_SH)
        @status = YAML.load(f.read)
      end
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
    File.open(stsfile, File::RDWR|File::CREAT) do |yml|
      yml.flock(File::LOCK_EX)
      yml.rewind
      YAML.dump(@status, yml)
      yml.flush
      yml.truncate(yml.pos)
    end
  end

  #一回分の活動
  def process()
    @status["wetsts"].process(@words, @status)
  end
end

# 自身を実行した場合にのみ起動
if __FILE__ == $PROGRAM_NAME then
  # 設定ファイル名指定
  savefile = $scriptdir + "/botsave.yml"
  wordsfile = $scriptdir + "/wordfile.yml"

  # コマンドライン解析
  args = cmdline

  # 必ずつぶやくモード
  if(args[:force]) then
    $always_tweet_flag = true
  end

  # botのインスタンス生成
  botobj = DiaperChangeBot.new(savefile, wordsfile)

  # bot処理実行
  botobj.process

  # 現状をコンソールに出力
  debugprint("現在の尿意：" + botobj.volume.to_s)
  debugprint("現在の状態：" + botobj.wetsts)

  # 状態をセーブ
  botobj.save(savefile)

end
