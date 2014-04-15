# coding: utf-8
# 人工無脳
require 'yaml'

class EnergyBot
	def energy
		return @status["energy"]
	end

	def initialize(stsfile = nil, wordsfile = nil)
		if stsfile == nil || !File.exist?(stsfile) then
			@status = {
				"energy" => 100
			}
		else
			@status = YAML.load_file(stsfile)
		end

		if wordsfile == nil || !File.exist?(wordsfile) then
			@words = {
				"charged" => [

					"まだ大丈夫。",
					"満腹。",
					"どうだろう。",
					"こんにちは。"
				],
				"empty" => [
					"だめだこれ。",
					"空腹。",
					"充電してください。",
					"つらい。"
				]
			}
		else
			@words = YAML.load_file(wordsfile)
		end
	end

	def setwords(words)
		@words = words
	end

	def speak()
		if @status["energy"] <= 0 then
			word = @words["empty"].sample
			if word == nil then
				word = "error: 空腹文字定義がnil。"
			end
		else
			word = @words["charged"].sample
			if word == nil then
				word = "error: 通常文字定義がnil。"
			end
		end

		puts word
	end

	#エネルギー消耗
	def consume()
		@status["energy"] = @status["energy"] - (rand(10) + 1)
		if @status["energy"] <= 0 then
			@status["energy"] = 0
		end
	end

	# セーブする。

	def save(stsfile)
		open(stsfile, "wb") do |yml|
			YAML.dump(@status, yml)
		end
	end

	#一回分の活動
	def process()
		#エネルギー消費
		consume

		#呼びかけに応答

		#充電確認

		#状態変更

		#自発的発言
		speak
	end
end

savefile = "botsave.yml"

botobj = EnergyBot.new(savefile)

botobj.process

puts "エネルギー残量：" + botobj.energy.to_s

botobj.save(savefile)