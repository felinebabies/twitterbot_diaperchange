@echo off

rem
rem ボットを実行する
rem

set CMD=ruby
set SCRIPT=bot.rb

rem このバッチが存在するフォルダをカレントに
pushd %0\..
cls

"%CMD%" "%SCRIPT%"

pause
exit