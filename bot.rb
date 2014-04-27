# coding: utf-8
# おむつ交換Bot
require 'yaml'
require 'twitter'
require 'pp'

# デバッグ出力
def debugprint(str)
	#puts (str.encode("CP932"))
	puts (str)
end

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

# ランダムなつぶやきを行うかの乱数判定
def talkrand()
	return(rand(20) == 0)
end

class StsBase
	# 尿意の最大増加値
	MAXINCREASEVAL = 10

	# がまんの閾値
	ENDURANCEBORDER = 280

	# お漏らしの閾値
	LEAKBORDER = 330

	# おむつ交換コマンド
	CHANGECOMMAND = "おむつ交換する"

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
		word = words["autonomous"][@modename].sample

		# コンソールにしゃべった内容を表示
		debugprint(word)

		# tweetする
		client = createclient
		client.update(word)
	end

	# 自分あての新しいメンションを取得する
	def getnewmentions(sts)
		client = createclient

		begin
			mentions = client.mentions()
		rescue
			puts "メンションを取得できませんでした。"
			newlist = []
		else
			newlist = mentions.select do |tweet|
				tweet.created_at > sts["lastmentiontime"]
			end
		end

		pp newlist

		return newlist
	end

	# メンション取得時刻を更新する
	def updatelastmentiontime(sts)
		sts["lastmentiontime"] = Time.now
	end

	# 回答セットから応答を抜き出す
	def getanswerstr(mentiontext, answerset)
		answerobj = answerset.select do |answerpair|
			pairs = answerpair["words"].select do |word|
				mentiontext.include?(word)
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


		return answertext
	end

	# 呼びかけに反応する
	def answertomentions(words, sts, mentions)
		client = createclient
		answerset = words["answerset"][@modename]

		mentions.each do |mention|
			answerstr = getanswerstr(mention.text, answerset)

			# ツイートする
			tweetstr = "@" + mention.user.screen_name + " " + answerstr
			client.update(tweetstr)

			# コンソールにしゃべった内容を表示
			debugprint(tweetstr)
		end
	end

	# 呼びかけに反応する
	def answer(words, sts)
		mentions = getnewmentions(sts)
		answertomentions(words, sts, mentions)
	end

	# 文字列におむつ交換コマンドが含まれていたらtrueを返す
	def includechange?(str)
		return str.include?(CHANGECOMMAND)
	end

	# おむつ交換の御礼を言う
	def saythanks(userid, words, islate = false)
		client = createclient

		objuser = client.user(userid)

		if islate then
			wordset = words["changeset"]["late"]
		else
			wordset = words["changeset"]["thanks"]
		end

		answerstr = wordset.sample

		# ツイートする
		tweetstr = "@" + objuser.screen_name + " " + answerstr
		client.update(tweetstr)

		# コンソールにしゃべった内容を表示
		debugprint(tweetstr)
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
					saythanks(mention.user.id, words)

					# 替えてくれた人にポイントをつける

					# 状態を変更する
					sts["wetsts"] = StsChanging.new

				else
					# 濡れていなければ御礼だけ言う
					saythanks(mention.user.id, words, true)
				end

				delmentions << mention.id
			end
		end

		# メンション配列から、返信済みのものを削除する
		mentions.delete_if do |mention|
			delmentions.include?(mention.id)
		end
	end

	# 就寝起床時刻設定
	def checksleep(sts)
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
			sts["wetsts"] = StsGotoSleep.new
			return
		end

		if (Time.now < sts["wakeuptime"]) && (! sts["wetsts"].sleeping?) then
			# 寝る
			sts["wetsts"] = StsGotoSleep.new
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
			sts["wetsts"] = StsWakeup.new
			return
		end
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

	# おむつが濡れているかを返す
	def diaperwet?()
		return false
	end

	# 寝ているかを返す
	def sleeping?()
		return false
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

		# 呼びかけに反応する
		answer(words, sts)
		updatelastmentiontime(sts)

		# 確率で自発的発言
		if talkrand() then
			sts["wetsts"].speak(words)
		end

		# 状態変更
		if(sts["volume"] >= ENDURANCEBORDER) then
			# 尿意が一定以上ならがまん状態にする
			sts["wetsts"] = StsEndurance.new

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
	def initialize()
		@modename = "endurance"
	end

	def process(words, sts)
		# 尿意増加
		increase(sts)

		# 呼びかけに反応する
		answer(words, sts)
		updatelastmentiontime(sts)

		# 確率で自発的発言
		if talkrand() then
			sts["wetsts"].speak(words)
		end

		# 状態変更
		if(sts["volume"] >= LEAKBORDER) then
			# 尿意が一定以上ならお漏らし状態にする
			sts["wetsts"] = StsLeak.new
		else
			# 変更が無ければ睡眠判定
			checksleep(sts)
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
		sts["wetsts"] = StsWet.new
	end
end

# 濡れた状態
class StsWet < StsBase
	# 初期化
	def initialize()
		@modename = "wet"
	end

	def process(words, sts)
		# メンション取得
		mentions = getnewmentions(sts)

		# おむつ交換判定
		changed = diaperchangecheck(sts, words, mentions)

		# 呼びかけに反応する
		answertomentions(words, sts, mentions)
		updatelastmentiontime(sts)

		# おむつを交換済みなら処理を終了する
		if changed then
			return
		end

		# 尿意増加
		increase(sts)

		# 確率で自発的発言
		if talkrand() then
			sts["wetsts"].speak(words)
		end

		# 状態変更
		if(sts["volume"] >= LEAKBORDER) then
			# 尿意が一定以上ならお漏らし状態にする
			sts["wetsts"] = StsLeak.new
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
	def initialize()
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
		sts["wetsts"] = StsFine.new
	end
end

# 寝入り状態
class StsGotoSleep < StsBase
	# 初期化
	def initialize()
		@modename = "gotosleep"
	end

	def process(words, sts)
		# 自発的発言
		sts["wetsts"].speak(words)

		# 状態変更
		sts["wetsts"] = StsSleeping.new
	end

	# 寝ているかを返す
	def sleeping?()
		return true
	end
end

# 睡眠中状態
class StsSleeping < StsBase
	# 初期化
	def initialize()
		@modename = "sleeping"
	end

	def process(words, sts)
		# 確率で自発的発言
		if talkrand() then
			sts["wetsts"].speak(words)
		end

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
	def initialize()
		@modename = "wakeup"
	end

	def process(words, sts)
		# 自発的発言
		sts["wetsts"].speak(words)

		# 状態変更
		# 必ずおねしょする
		sts["wetsts"] = StsWet.new
	end

	# 寝ているかを返す
	def sleeping?()
		return true
	end
end

class DiaperChangeBot
	# 状態定数
	STS_FINE	= 0 # 普通
	STS_ENDURANCE	= 1 # 我慢
	STS_LEAK	= 2 # お漏らし
	STS_WET		= 3 # 濡れてる
	STS_CHANGING	= 4 # おむつ交換中
	STS_GOTOSLEEP	= 5 # 寝入り
	STS_SLEEPING	= 6 # 睡眠中
	STS_WAKEUP	= 7 # 起床（必ずおねしょする）

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

# 設定ファイル名指定
savefile = "botsave.yml"
wordsfile = "wordfile.yml"

# botのインスタンス生成
botobj = DiaperChangeBot.new(savefile, wordsfile)

# bot処理実行
botobj.process

# 現状をコンソールに出力
debugprint("現在の尿意：" + botobj.volume.to_s)
debugprint("現在の状態：" + botobj.wetsts)

# 状態をセーブ
botobj.save(savefile)