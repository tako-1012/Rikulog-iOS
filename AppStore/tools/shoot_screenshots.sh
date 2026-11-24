#!/bin/zsh
# usage: shoot_screenshots.sh <out_dir> [en|ja]
# 事前に DEBUG ビルドを iPhone 17 Pro Max シミュレータにインストールしておくこと
OUT=${1:?out dir}
LANG_CODE=${2:-en}
SIM=${SIM:-43A7A62F-3B08-4304-96D1-C9A6B03EA220}
LOCALE=$([ "$LANG_CODE" = "ja" ] && echo ja_JP || echo en_US)
mkdir -p $OUT
xcrun simctl status_bar $SIM override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
for screen in records detail pb share calculator treadmill profile; do
  xcrun simctl launch --terminate-running-process $SIM com.kotaro.riku-log -screenshotMode YES -screenshotScreen $screen -debug_premium_enabled YES -AppleLanguages "($LANG_CODE)" -AppleLocale $LOCALE >/dev/null
  sleep 8
  xcrun simctl io $SIM screenshot $OUT/$screen.png >/dev/null 2>&1 && echo "shot $screen"
done
