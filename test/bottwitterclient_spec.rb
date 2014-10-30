# coding: utf-8

require_relative '../bottwitterclient'

describe BotTwitterClient do
  it "should ../tsettings.yml is exist" do
    expect(File.exists?('../tsettings.yml')).to eq true
  end

  it "BotTwitterClient.instance not to be nil" do
    expect(BotTwitterClient.instance).not_to eq nil
  end

  it "createclient() not to be nil" do
    expect(createclient()).not_to eq nil
  end
end
