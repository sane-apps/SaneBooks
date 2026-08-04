#!/bin/bash
# Repair Xcode's embedded libzcashlc copy into Apple's required versioned
# macOS framework layout after the package copy phase flattens symlinks.

set -euo pipefail

if [ -z "${TARGET_BUILD_DIR:-}" ] || [ -z "${FRAMEWORKS_FOLDER_PATH:-}" ]; then
  echo "error: TARGET_BUILD_DIR and FRAMEWORKS_FOLDER_PATH are required"
  exit 1
fi

framework="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/libzcashlc.framework"

if [ ! -d "${framework}" ]; then
  echo "error: embedded libzcashlc framework is missing at ${framework}"
  exit 1
fi

if [ -f "${framework}/Versions/Current/Resources/Info.plist" ]; then
  echo "libzcashlc already uses the required versioned macOS framework layout"
  exit 0
fi

mkdir -p "${framework}/Versions/A/Resources"

move_if_needed() {
  source_path="$1"
  destination_path="$2"
  if [ -e "${destination_path}" ]; then
    return
  fi
  if [ ! -e "${source_path}" ]; then
    echo "error: refusing to repair unexpected libzcashlc layout; missing ${source_path}"
    exit 1
  fi
  mv "${source_path}" "${destination_path}"
}

# Each move is independently recoverable so an interrupted build can safely retry.
move_if_needed "${framework}/libzcashlc" "${framework}/Versions/A/libzcashlc"
move_if_needed "${framework}/Info.plist" "${framework}/Versions/A/Resources/Info.plist"
move_if_needed "${framework}/Headers" "${framework}/Versions/A/Headers"
move_if_needed "${framework}/Modules" "${framework}/Versions/A/Modules"
ln -sfn A "${framework}/Versions/Current"
ln -sfn Versions/Current/libzcashlc "${framework}/libzcashlc"
ln -sfn Versions/Current/Resources "${framework}/Resources"
ln -sfn Versions/Current/Headers "${framework}/Headers"
ln -sfn Versions/Current/Modules "${framework}/Modules"

echo "Repaired embedded libzcashlc into a versioned macOS framework layout"
