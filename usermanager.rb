# coding: utf-8

require 'yaml'
require_relative 'bottwitterclient'

# ユーザ管理クラス
class UserManager
  attr_reader :userdata
  def initialize(userDataFile)
    @userDataFile = userDataFile

    # ユーザ情報ファイルの読み込み
    load
  end

  # ユーザ情報ファイルの読み込み
  def load
    if File.exist?(@userDataFile) then
      File.open(@userDataFile, "r") do |f|
        f.flock(File::LOCK_SH)
        @userdata = YAML.load(f.read)
      end
    else
      @userdata = []
    end
  end

  # データをファイルに保存する
  def save
    File.open(@userDataFile, File::RDWR|File::CREAT) do |yml|
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
      return false
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
    return true
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