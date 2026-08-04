#!/usr/bin/env bash
# Canonical Mini E2E: private Zashi DB import scenes run inside the UI test target.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB="${SANEBOOKS_E2E_ZASHI_DB:-${HOME}/Library/Application Support/SaneBooks-e2e/ZcashSdk_mainnet_data.db}"

if [[ ! -f "$DB" ]]; then
  echo "SaneBooks private Zashi E2E fixture is missing: $DB" >&2
  exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "SaneBooks private Zashi E2E is Mini-only." >&2
  exit 1
fi

export SANEBOOKS_E2E_ZASHI_DB="$DB"
export SANEBOOKS_FORCE_MOCK=1
export SANEAPPS_DISABLE_KEYCHAIN=1

cd "$ROOT"
exec ./scripts/SaneMaster.rb verify --ui --timeout 1800
