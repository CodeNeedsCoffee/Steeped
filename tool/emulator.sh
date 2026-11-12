#!/usr/bin/env bash
# Start the low-memory steeped_test AVD detached, wait for boot, then stop with: tool/emulator.sh stop; mirror it with: tool/emulator.sh view (needs scrcpy)
set -euo pipefail
SDK="${ANDROID_HOME:-$HOME/Utils/android-sdk}"
if [ "${1:-}" = stop ]; then "$SDK/platform-tools/adb" emu kill; exit 0; fi
if [ "${1:-}" = view ]; then exec setsid scrcpy -s emulator-5554 --window-title Steeped-emulator >/dev/null 2>&1; fi
cd /tmp
setsid nohup "$SDK/emulator/emulator" -avd steeped_test -no-window -no-audio -no-snapshot \
  -no-boot-anim -gpu host -cores 2 -memory 1536 -no-metrics >/tmp/steeped_emulator.log 2>&1 </dev/null &
"$SDK/platform-tools/adb" wait-for-device
until [ "$("$SDK/platform-tools/adb" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; do sleep 3; done
echo "emulator booted"
