# coding: utf-8

require_relative 'usermanager'
require_relative 'bottwitterclient'

# 置換処理基底クラス
class ReplaceBase
  def process(str, mention, maxlen)
    return str
  end
end

# ランキング置換
class ReplaceChangeRanking < ReplaceBase
  KEYWORD = '<showranking>'
  def process(str, mention, maxlen)
    if str.include?(KEYWORD) then
      # おむつ交換ランキングを取得する
      manager = UserManager.new($scriptdir + "/savedata/userdata.yml")
      userdatas = manager.userdata

      if userdatas.empty? then
        newstr = str.gsub(KEYWORD, "まだおむつ交換してくれた人はいないの。")
        return newstr
      end

      # ランク順にソート
      userdatas.sort! do |a, b|
        b["diaperchangepoint"] <=> a["diaperchangepoint"]
      end

      # クライアントを取得
      client = createclient()

      # メンション先ユーザIDの初期化
      mentionuserid = nil

      # 文字列の先頭部分を作成
      if mention then
        mentionuser = userdatas.select do |user|
          user["id"] == mention.user.id
        end

        if mentionuser.empty? then
          headstr = "今までおむつを替えてくれた数は、"
        else
          mentionuserid = mentionuser.first["id"]
          headstr = "さんは、#{mentionuser.first["diaperchangepoint"].to_s}回おむつを替えてくれたよ。"
        end
      else
        headstr = "今までおむつを替えてくれた数は、"
      end

      nextrankstr = String.new(headstr)

      rankcount = 0
      tweetlength = str.gsub(KEYWORD, headstr).size
      while tweetlength <= maxlen do
        if(! userdatas[rankcount]) then
          break
        end

        if(mentionuserid && (mentionuserid == userdatas[rankcount]["id"])) then
          # ランクのカウントを進める
          rankcount += 1
          next
        end

        # トップランカーの表示名を取得
        begin
          rankeruser = client.user(userdatas[rankcount]["id"])
        rescue
          # 存在しないユーザの場合はスキップ
          # ランクのカウントを進める
          rankcount += 1
          next
        end
        rankername = rankeruser.screen_name

        catrankstr = nextrankstr

        # ランク文字列を作成
        rankstr = "#{rankername}さんは、#{userdatas[rankcount]["diaperchangepoint"].to_s}回。"

        nextrankstr = catrankstr + rankstr

        # tweetlengthを更新
        tweetlength = str.gsub(KEYWORD, nextrankstr).size

        # ランクのカウントを進める
        rankcount += 1
      end

      # 文字列の置き換えを行う
      newstr = str.gsub(KEYWORD, catrankstr)

      return newstr
    else
      return str
    end
  end
end

# 特殊なメッセージを置換する
def replacespecialmessage(tweetstr, mention, maxlen)
  commandarr = [
    ReplaceChangeRanking.new
  ]

  commandarr.each do |command|
    tweetstr = command.process(tweetstr, mention, maxlen)
  end

  return tweetstr
end
