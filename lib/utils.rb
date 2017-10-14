# coding: utf-8
# bot陽ユーティリティ
require 'bundler'
Bundler.require

module DiaperChangeBot
  # デバッグ出力
  def debugprint(str)
    #puts (str.encode("CP932"))
    puts(str)
  end

  # ランダムなつぶやきを行うかの乱数判定
  def talkrand()
    if($always_tweet_flag == true) then
      return(true)
    else
      return(rand(20) == 0)
    end
  end

  module_function :debugprint
  module_function :talkrand
end
