#!/bin/zsh
S=/private/tmp/claude-501/-Users-kotaro-Developer-Raceaster/ed9d6e79-0015-437a-bf52-a43a51b63aec/scratchpad
SIM=43A7A62F-3B08-4304-96D1-C9A6B03EA220
for screen in records detail pb share calculator treadmill profile; do
  xcrun simctl launch --terminate-running-process $SIM com.kotaro.riku-log -screenshotMode YES -screenshotScreen $screen -debug_premium_enabled YES -AppleLanguages "(en)" -AppleLocale en_US >/dev/null
  sleep 8
  xcrun simctl io $SIM screenshot $S/shots/$screen.png >/dev/null 2>&1 && echo "shot $screen"
done
