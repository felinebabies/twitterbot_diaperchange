# coding: utf-8
# おむつ交換Bot
require 'yaml'
require 'twitter'

# twitterクライアントを生成する
def createclient()
	tsettings = YAML.load_file("tsettings.yml")

	client = Twitter::REST::Client.new do |config|
		config.consumer_key        = tsettings["consumer_key"]
		config.consumer_secret     = tsettings["consumer_secret"]
		config.access_token        = tsettings["access_token"]
		config.access_token_secret = tsettings["access_token_secret"]
	end

	return client
end

class StsBase
	# 尿意の最大増加値
	MAXINCREASEVAL = 10

	# がまんの閾値
	ENDURANCEBORDER = 60

	# お漏らしの閾値
	LEAKBORDER = 75

	# 初期化
	def initialize()
		@modename = "fine"
	end

	# 尿意増加
	def increase(status)
		status["volume"] = status["volume"] + (rand(MAXINCREASEVAL) + 1)
	end

	# 喋る
	def speak(words)
		word = words[@modename].sample
		puts (word.encode("CP932"))

		# tweetする
		client = createclient
		client.update(word)
	end

	# 行動セット呼び出し
	def process(words, sts)
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
end

# おむつが乾いた状態
class StsFine < StsBase
	# 初期化
	def initialize()
		@modename = "fine"
	end

	def process(words, sts)
		# 尿意増加
		increase(sts)

		# 状態変更
		if(sts["volume"] >= ENDURANCEBORDER) then
			# 尿意が一定以上ならがまん状態にする
			sts["wetsts"] = StsEndurance.new

			# 状態変更時は強制発言
			sts["wetsts"].speak(words)
		else
			# 確率で自発的発言
			if rand(20) == 0 then
				sts["wetsts"].speak(words)
			end
		end
	end
end

# がまん状態
class StsEndurance < StsBase
	# 初期化
	def initialize()
		@modename = "endurance"
	end

	def process(words, sts)
		# 尿意増加
		increase(sts)

		# 状態変更
		if(sts["volume"] >= LEAKBORDER) then
			# 尿意が一定以上ならお漏らし状態にする
			sts["wetsts"] = StsLeak.new

			# 漏らした時刻を更新する
			sts["leaktime"] = Time.now

			# 状態変更時は強制発言
			sts["wetsts"].speak(words)
		else
			# 確率で自発的発言
			if rand(20) == 0 then
				sts["wetsts"].speak(words)
			end
		end
	end
end

# お漏らし状態
class StsLeak < StsBase
	# 初期化
	def initialize()
		@modename = "leak"
	end

	def process(words, sts)
		# 尿意をリセットする
		sts["volume"] = 0

		# 状態変更
		sts["wetsts"] = StsWet.new

		# 自発的発言
		sts["wetsts"].speak(words)
	end
end

# 濡れた状態
class StsWet < StsBase
	# 初期化
	def initialize()
		@modename = "wet"
	end

	def process(words, sts)
		# おむつ交換判定

		# 尿意増加
		increase(sts)

		# 状態変更
		if(sts["volume"] >= LEAKBORDER) then
			# 尿意が一定以上ならお漏らし状態にする
			sts["wetsts"] = StsLeak.new

			# 漏らした時刻を更新する
			sts["leaktime"] = Time.now

			# 状態変更時は強制発言
			sts["wetsts"].speak(words)
		else
			# 確率で自発的発言
			if rand(20) == 0 then
				sts["wetsts"].speak(words)
			end
		end
	end
end

# おむつ交換中状態
class StsChanging < StsBase
	# 初期化
	def initialize()
		@modename = "changing"
	end

	def process(words, sts)
		# 尿意増加
		increase(sts)

		# 状態変更
		sts["wetsts"] = StsFine.new

		# 自発的発言
		sts["wetsts"].speak(words)
	end
end

class DiaperChangeBot
	# 状態定数
	STS_FINE	= 0 # 普通
	STS_ENDURANCE	= 1 # 我慢
	STS_LEAK	= 2 # お漏らし
	STS_WET		= 3 # 濡れてる
	STS_CHANGING	= 4 # おむつ交換中

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
				"leaktime" => Time.now
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
				]
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

savefile = "botsave.yml"

botobj = DiaperChangeBot.new(savefile)

botobj.process

puts ("現在の尿意：" + botobj.volume.to_s).encode("CP932")
puts ("現在の状態：" + botobj.wetsts).encode("CP932")

botobj.save(savefile)