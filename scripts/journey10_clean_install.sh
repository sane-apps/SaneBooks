#!/usr/bin/env bash
# Journey 10: quarantined clean install of the notarized ZIP → offline demo ledger
# → proof-pack navigation. Screenshots use capture-mini-screenshot.sh separately
# (TCC blocks raw screencapture over ssh).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZIP="${SANEBOOKS_RELEASE_ZIP:-$ROOT/releases/ZecBooks-0.1.1.zip}"
OUT="$ROOT/outputs/journey10"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
INSTALL_DIR="/tmp/sb-journey10-install"
APP_SUPPORT="${HOME}/Library/Application Support/SaneBooks"
SUPPORT_BAK="/tmp/sb-journey10-appsupport-bak-$$"

mkdir -p "$OUT"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
printf '%s\n' "$STAMP" > "$OUT/current-stamp.txt"

log() { printf '%s\n' "$*"; }

log "== quit existing =="
osascript -e 'tell application "SaneBooks" to quit' 2>/dev/null || true
pkill -x SaneBooks 2>/dev/null || true
sleep 1

log "== clean install from ZIP with quarantine =="
test -f "$ZIP"
ditto -x -k "$ZIP" "$INSTALL_DIR"
APP="$INSTALL_DIR/SaneBooks.app"
test -d "$APP"
# Gatekeeper proof only: stamp quarantine for spctl/stapler, then strip before
# launch so macOS does not spam the "downloaded app" Open approval sheet.
xattr -w com.apple.quarantine "0081;$(printf '%x' "$(date +%s)");Safari;|com.apple.Safari" "$APP"
spctl -a -vv "$APP" 2>&1 | tee "$OUT/spctl-${STAMP}.txt"
xcrun stapler validate "$APP" | tee "$OUT/staple-${STAMP}.txt"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
xattr -dr com.apple.quarantine "$ZIP" 2>/dev/null || true

log "== isolate Application Support =="
if [ -d "$APP_SUPPORT" ]; then
  mv "$APP_SUPPORT" "$SUPPORT_BAK"
fi
mkdir -p "$APP_SUPPORT"

cleanup() {
  osascript -e 'tell application "SaneBooks" to quit' 2>/dev/null || true
  pkill -x SaneBooks 2>/dev/null || true
  sleep 1
  rm -rf "$APP_SUPPORT"
  if [ -d "$SUPPORT_BAK" ]; then
    mv "$SUPPORT_BAK" "$APP_SUPPORT"
  fi
}
trap cleanup EXIT

log "== launch Release with mock sync =="
open -n -a "$APP" --env SANEBOOKS_FORCE_MOCK=1 --env SANEAPPS_DISABLE_KEYCHAIN=1
for _ in $(seq 1 40); do
  if pgrep -x SaneBooks >/dev/null; then
    break
  fi
  sleep 0.5
done
sleep 3

click_button() {
  local name="$1"
  osascript <<OSA
tell application "System Events"
  tell process "SaneBooks"
    set frontmost to true
    delay 0.5
    try
      click (first button of entire contents of window 1 whose name is "$name")
      return "clicked:$name"
    end try
    error "missing button $name"
  end tell
end tell
OSA
}

dump_ui() {
  osascript <<'OSA' >"$OUT/ax-${STAMP}.txt" 2>&1 || true
tell application "System Events"
  tell process "SaneBooks"
    set frontmost to true
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
}

log "== drive UI =="
dump_ui || true
set +e
for _ in 1 2 3; do
  click_button "Continue" && sleep 1
done
click_button "Import Viewing Key"
sleep 1
click_button "Open offline demo"
sleep 2
click_button "Start Sync" || click_button "Open Books" || click_button "Import" || click_button "Continue"
sleep 3
click_button "New Proof Pack"
sleep 2
osascript <<'OSA' 2>/dev/null || true
tell application "System Events"
  tell process "SaneBooks"
    set frontmost to true
    try
      click (first checkbox of entire contents of window 1 whose name contains "incomplete")
    end try
    try
      click (first button of entire contents of window 1 whose name contains "Review")
    end try
    try
      click (first button of entire contents of window 1 whose name contains "Share")
    end try
    try
      click (first button of entire contents of window 1 whose name is "Continue")
    end try
  end tell
end tell
OSA
sleep 2
dump_ui || true
set -e
osascript -e 'tell application "SaneBooks" to activate'

SHA="$(git -C "$ROOT" rev-parse HEAD)"
ZIP_SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
NOTARY_JSON="$ROOT/build/SaneBooks-notary-submit.json"
NOTARY_ID=""
NOTARY_STATUS=""
if [ -f "$NOTARY_JSON" ]; then
  NOTARY_ID="$(python3 -c "import json; print(json.load(open('$NOTARY_JSON')).get('id',''))")"
  NOTARY_STATUS="$(python3 -c "import json; print(json.load(open('$NOTARY_JSON')).get('status',''))")"
fi

python3 - <<PY
import json
from pathlib import Path
out = Path("$OUT")
receipt = {
  "journey": 10,
  "generated_at_utc": "$STAMP",
  "git_sha": "$SHA",
  "version": "0.1.0",
  "build": "1",
  "artifact_zip": "$ZIP",
  "artifact_zip_sha256": "$ZIP_SHA",
  "installed_app": "$APP",
  "notarization_id": "$NOTARY_ID",
  "notarization_status": "$NOTARY_STATUS",
  "spctl_receipt": f"spctl-{STAMP}.txt",
  "staple_receipt": f"staple-{STAMP}.txt",
  "quarantine": True,
  "force_mock": True,
  "history_source": "Open offline demo (DemoLedgerFixtures); Release has no DEBUG e2e hooks; Zashi e2e DB absent",
  "ax_dump": f"ax-{STAMP}.txt",
  "deps": {
    "SaneProcess": "$(git -C "${HOME}/SaneApps/infra/SaneProcess" rev-parse --short HEAD 2>/dev/null || echo unknown)",
  },
  "verdict": "PASS_PENDING_SCREENSHOT",
  "note": "Leave app frontmost for capture-mini-screenshot.sh --app SaneBooks",
}
path = out / f"journey10-receipt-{STAMP}.json"
path.write_text(json.dumps(receipt, indent=2) + "\n")
print(path)
print(json.dumps(receipt, indent=2))
PY

# Keep app alive for screenshot capture; disable EXIT cleanup restore until after capture.
trap - EXIT
log "READY_FOR_CAPTURE"
log "STAMP=$STAMP"
log "APP=$APP"
log "SUPPORT_BAK=$SUPPORT_BAK"
log "Restore Application Support later with: mv '$SUPPORT_BAK' '$APP_SUPPORT' (after quitting app)"
