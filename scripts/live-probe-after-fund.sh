#!/usr/bin/env bash
# Canonical funded Ironwood receive gate. It is expected to fail until the
# public view-only probe key has at least one confirmed Ironwood receive.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "${SANEBOOKS_FUNDED_LIVE_RECEIPT:-0}" != "1" ]]; then
  echo "Refusing an unfunded/accidental live receipt run." >&2
  echo "After the owner funds the public view-only probe address, rerun with SANEBOOKS_FUNDED_LIVE_RECEIPT=1." >&2
  exit 1
fi

export SANEBOOKS_LIVE_LWD=1
export SANEBOOKS_FUNDED_LIVE_RECEIPT=1

cd "$ROOT"
exec ./scripts/SaneMaster.rb verify --timeout 1800
