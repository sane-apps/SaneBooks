#!/usr/bin/env bash
# Run inside Mini GUI Terminal (mini-gui-run.sh) for Accessibility.
set -euo pipefail
APP="${1:-/tmp/sb-journey10-install/SaneBooks.app}"
OUT="${2:-$HOME/SaneApps/apps/SaneBooks/outputs/journey10}"
STAMP="${3:-$(date -u +%Y%m%dT%H%M%SZ)}"
mkdir -p "$OUT"
export SANEBOOKS_FORCE_MOCK=1
export SANEAPPS_DISABLE_KEYCHAIN=1

osascript -e 'tell application "SaneBooks" to quit' 2>/dev/null || true
pkill -x SaneBooks 2>/dev/null || true
sleep 1
open -n -a "$APP"
sleep 5

osascript <<OSA | tee "$OUT/ax-${STAMP}.txt"
tell application "System Events"
  tell process "SaneBooks"
    set frontmost to true
    delay 1
    set names to {}
    try
      repeat with b in (buttons of entire contents of window 1)
        try
          set end of names to (name of b as text)
        end try
      end repeat
    end try
    set AppleScript's text item delimiters to linefeed
    return names as text
  end tell
end tell
OSA

click_named() {
  local name="$1"
  osascript -e "tell application \"System Events\" to tell process \"SaneBooks\" to click (first button of entire contents of window 1 whose name is \"$name\")" \
    && echo "clicked:$name" || echo "missing:$name"
}

for _ in 1 2 3; do click_named "Continue"; sleep 1; done
click_named "Import Viewing Key"; sleep 1
click_named "Open offline demo"; sleep 2
click_named "Start Sync" || true
click_named "Open Books" || true
click_named "Continue" || true
sleep 2
click_named "New Proof Pack"; sleep 2

osascript <<'OSA' || true
tell application "System Events"
  tell process "SaneBooks"
    set frontmost to true
    try
      click (first checkbox of entire contents of window 1 whose name contains "incomplete")
    end try
    try
      click (first button of entire contents of window 1 whose name contains "Review")
    end try
  end tell
end tell
OSA

osascript -e 'tell application "SaneBooks" to activate'
echo READY_FOR_CAPTURE
echo STAMP=$STAMP
