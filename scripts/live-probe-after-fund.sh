#!/usr/bin/env bash
# Bound wait for ≥1 note on LiveProbeKey after dust send. Mini-first.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/SaneBooksPackage"
export SANEBOOKS_USE_LOCAL_SANEUI=1
export SANEBOOKS_LIVE_LWD=1
rm -rf "${HOME}/Library/Application Support/SaneBooks/zcash-sdk" 2>/dev/null || true
echo "live-probe-after-fund: starting (max ~20 min)"
# Reuse package test filter — expect catch-up; note count checked via companion watch if needed
swift test --filter liveProbeKeyImportsAndSyncs
echo "live-probe-after-fund: base smoke ok — run SaneBooksWatch-style note wait next if notes still 0"
