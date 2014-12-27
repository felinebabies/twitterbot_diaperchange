# coding: utf-8

require_relative '../lib/bottwitterclient'

describe BotTwitterClient do
  it "should ../savedata/tsettings.yml is exist" do
    expect(File.exists?('../savedata/tsettings.yml')).to eq true
  end

  it "BotTwitterClient.instance not to be nil" do
    expect(BotTwitterClient.instance).not_to eq nil
  end

  it "createclient() not to be nil" do
    expect(createclient()).not_to eq nil
  end
end
