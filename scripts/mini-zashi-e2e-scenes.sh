#!/usr/bin/env bash
# Mini E2E: Zashi DB import → ledger/detail/pack/share + screenshots
set -euo pipefail
APP="${HOME}/SaneApps/apps/SaneBooks/build/DerivedData/Build/Products/Debug/SaneBooks.app"
DB="${HOME}/Library/Application Support/SaneBooks-e2e/ZcashSdk_mainnet_data.db"
OUT="${HOME}/SaneApps/apps/SaneBooks/outputs/visual-audit-sanebooks/gold-zashi-e2e"
LOGDIR="/tmp/sanebooks-e2e-logs"
CAP="${HOME}/SaneApps/infra/SaneProcess/scripts/mini/capture-mini-screenshot.sh"
# When run via ssh mini, capture from controller — so we capture via local script calling mini

mkdir -p "$OUT" "$LOGDIR"
pkill -x SaneBooks 2>/dev/null || true
sleep 1

launch_scene() {
  local scene="$1"
  local log="$LOGDIR/${scene}.log"
  pkill -x SaneBooks 2>/dev/null || true
  sleep 1
  # Clear vault between welcome/import only; keep data for zashi scenes after first import
  if [[ "$scene" == "welcome" || "$scene" == "import" ]]; then
    rm -rf "${HOME}/Library/Application Support/SaneBooks" 2>/dev/null || true
  fi
  echo "LAUNCH scene=$scene $(date -u +%H:%M:%S)" | tee -a "$LOGDIR/runner.log"
  open -a "$APP" --args \
    "--e2e-import-db=${DB}" \
    "--e2e-scene=${scene}" \
    >>"$log" 2>&1 &
  # Bound wait for window
  for i in $(seq 1 40); do
    if pgrep -x SaneBooks >/dev/null; then
      sleep 2
      return 0
    fi
    sleep 0.5
  done
  echo "FAIL launch $scene" >&2
  return 1
}

# First import clears store
rm -rf "${HOME}/Library/Application Support/SaneBooks" 2>/dev/null || true

for scene in zashi-ledger zashi-detail zashi-pack zashi-share; do
  launch_scene "$scene"
  sleep 3
  # Front app
  osascript -e 'tell application "SaneBooks" to activate' 2>/dev/null || true
  sleep 1
  echo "READY $scene" | tee -a "$LOGDIR/runner.log"
  # Marker file for controller to screenshot
  echo "$scene" > "$LOGDIR/current-scene.txt"
  # Hold scene for capture window (controller polls)
  sleep 8
done

# Also welcome + import chrome (gold theme) without wiping after zashi
pkill -x SaneBooks 2>/dev/null || true
sleep 1
open -a "$APP" --args "--e2e-scene=welcome" >>"$LOGDIR/welcome.log" 2>&1 &
sleep 4
osascript -e 'tell application "SaneBooks" to activate' 2>/dev/null || true
echo "welcome" > "$LOGDIR/current-scene.txt"
sleep 6

pkill -x SaneBooks 2>/dev/null || true
sleep 1
open -a "$APP" --args "--e2e-scene=import" >>"$LOGDIR/import.log" 2>&1 &
sleep 4
osascript -e 'tell application "SaneBooks" to activate' 2>/dev/null || true
echo "import" > "$LOGDIR/current-scene.txt"
sleep 6

echo "DONE_ALL" > "$LOGDIR/current-scene.txt"
echo "E2E runner finished"
