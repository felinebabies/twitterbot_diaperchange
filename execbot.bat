@echo off

rem
rem �{�b�g�����s����
rem

set CMD=ruby
set SCRIPT=bot.rb

rem ���̃o�b�`�����݂���t�H���_���J�����g��
pushd %0\..
cls

"%CMD%" "%SCRIPT%"

pause
exit