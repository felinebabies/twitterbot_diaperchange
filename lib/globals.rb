# coding: utf-8
# グローバル設定
require 'bundler'
Bundler.require

module DiaperChangeBot
  # 当スクリプトファイルの所在
  $scriptdir = File.join(File.expand_path(File.dirname(__FILE__)), "../")

  # セーブデータ用ディレクトリの所在
  $savedir = File.join($scriptdir, 'savedata/')

  # 一日中寝ないモード
  DEBUG_NO_SLEEP = true

  # ランダムなつぶやきを必ず実行するフラグ
  $always_tweet_flag = false
end
