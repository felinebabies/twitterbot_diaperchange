# coding: utf-8
# おむつ交換Bot
require 'yaml'
require 'twitter'
require 'pp'

# 当スクリプトファイルの所在
$scriptdir = File.expand_path(File.dirname(__FILE__))

# 一日中寝ないモード
DEBUG_NO_SLEEP = false

# デバッグ出力
def debugprint(str)
	#puts (str.encode("CP932"))
	puts (str)
end

# twitterクライアントを生成する
def createclient()
	tsettings = YAML.load_file($scriptdir + "/tsettings.yml")

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

# 置換処理基底クラス
class ReplaceBase
	def process(str)
		return str
	end
end

# ランキング置換
class ReplaceChangeRanking < ReplaceBase
	KEYWORD = "<showranking>"
	def process(str)
		if str.include?(KEYWORD) then
			# おむつ交換ランキングを取得する
			manager = UserManager.new
			userdatas = manager.userdata

			if userdatas.empty? then
				newstr = str.gsub(KEYWORD, "まだおむつ交換してくれた人はいないの。")
				return newstr
			end

			userdatas.sort! do |a, b|
				b["diaperchangepoint"] <=> a["diaperchangepoint"]
			end

			# トップランカーの表示名を取得
			client = createclient()
			topuser = client.user(userdatas.first["id"])
			topname = topuser.screen_name

			rankstr = "今までいちばん多くおむつを交換してくれたのは、" +
				userdatas.first["diaperchangepoint"].to_s +
				"回交換してくれた" + topname + "だよ。"

			newstr = str.gsub(KEYWORD, rankstr)

			return newstr
		else
			return str
		end
	end
end

# 特殊なメッセージを置換する
def replacespecialmessage(tweetstr)
	commandarr = [
		ReplaceChangeRanking.new
	]

	commandarr.each do |command|
		tweetstr = command.process(tweetstr)
	end

	return tweetstr
end

# ユーザ管理クラス
class UserManager
	USERDATAFILE = $scriptdir + "/userdata.yml"

	attr_reader :userdata

	def initialize
		# ユーザ情報ファイルの読み込み
		load
	end

	# ユーザ情報ファイルの読み込み
	def load
		if File.exist?(USERDATAFILE) then
			File.open(USERDATAFILE, "r") do |f|
				f.flock(File::LOCK_SH)
				@userdata = YAML.load(f.read)
			end
		else
			@userdata = []
		end
	end

	# データをファイルに保存する
	def save
		File.open(USERDATAFILE, File::RDWR|File::CREAT) do |yml|
			yml.flock(File::LOCK_EX)
			yml.rewind
			YAML.dump(@userdata, yml)
			yml.flush
			yml.truncate(yml.pos)
		end
	end

	# ユーザを追加
	def adduser(userid)
		userobj = {
			"id" => userid,
			"diaperchangepoint" => 0,
			"calledname" => "",
			"interestpoint" => 0,
			"displayname" => ""
		}

		@userdata << userobj
	end

	# ユーザオブジェクトを取得、存在しなければnilを返す
	def getuser(userid)
		userobj = @userdata.select do |user|
			user["id"] == userid
		end

		return userobj.first
	end

	# ユーザオブジェクトの更新
	def update(userobj)
		# 指定IDのインデックスを取得する
		if userobj.has_key?("id") then
			uid = userobj["id"]
		else
			warn("update:引数は正しいユーザオブジェクトではありません。")
			return
		end

		objindex = @userdata.index do |user|
			user["id"] == uid
		end

		if objindex == nil then
			# 存在しない場合、新たにユーザを追加する
			adduser(uid)

			objindex = @userdata.index do |user|
				user["id"] == uid
			end
		end

		# ユーザ表示名を更新する
		updatedispname(userobj)

		@userdata[objindex] = userobj.dup
	end

	# おむつ交換ポイントを取得する
	def getchangepoint(userid)
		user = getuser(userid)
		if user == nil then
			warn("getchangepoint:指定のユーザが存在しませんでした。" + userid.to_s)
			return 0
		end

		return user["diaperchangepoint"]
	end

	# おむつ交換ポイントに加算する
	def addchangepoint(userid, val)
		userobj = getuser(userid)
		if userobj == nil then
			# 存在しなければオブジェクトを作成
			userobj = {
				"id" => userid,
				"diaperchangepoint" => 0,
				"calledname" => "",
				"interestpoint" => 0,
				"displayname" => ""
			}
		end

		userobj["diaperchangepoint"] += val

		update(userobj)
	end

	# ユーザー表示名を更新する
	def updatedispname(userdata)
		client = createclient()

		begin
			userobj = client.user(userdata["id"])

			userdata["displayname"] = userobj.name
		rescue
			warn(userdata["id"].to_s + "のユーザ情報を取得できませんでした。")
		end
	end

	# ユーザー表示名を全て更新する
	def updatedispnameall()
		@userdata.each do |userdata|
			updatedispname(userdata)
		end
	end
end

class StsBase
	# 尿意の最大増加値
	MAXINCREASEVAL = 10

	# がまんの閾値
	ENDURANCEBORDER = 280

	# お漏らしの閾値
	LEAKBORDER = 330

	# おむつ交換コマンド
	CHANGECOMMAND = [
		"おむつ交換する",
		"おむつ交換します",
		"おむつ交換してあげる",
		"おむつを交換する",
		"おむつを交換します",
		"おむつを交換してあげる",
		"オムツ交換する",
		"オムツ交換します",
		"オムツ交換してあげる",
		"オムツを交換する",
		"オムツを交換します",
		"オムツを交換してあげる",
		"おむつ交換しよう",
		"オムツ交換しよう",
		"おむつを交換しよう",
		"オムツを交換しよう"
	]

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

		# 文字列の置き換えを行う
		word = replacespecialmessage(word)

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
			newlist = mentions.select do |tweet|
				tweet.created_at > sts["lastmentiontime"]
			end
		rescue
			warn("メンションを取得できませんでした。")
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

		pp newlist

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
		answertext = replacespecialmessage(answertext)

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
			client.update(tweetstr, :in_reply_to_status_id => mention.id)

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
		changeset = CHANGECOMMAND.select do |pattern|
			str.include?(pattern)
		end
		return ! changeset.empty?
	end

	# おむつ交換の御礼を言う
	def saythanks(mention, words, islate = false)
		client = createclient

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
					saythanks(mention, words)

					# 替えてくれた人にポイントをつける
					manager = UserManager.new
					manager.addchangepoint(mention.user.id, 1)
					manager.save

					# 状態を変更する
					sts["wetsts"] = StsChanging.new

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
	def initialize()
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
		sts["wetsts"] = StsWet.new
	end

	# 寝ているかを返す
	def sleeping?()
		return true
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