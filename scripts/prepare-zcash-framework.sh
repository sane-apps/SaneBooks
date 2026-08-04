#!/bin/bash
# Repair Xcode's embedded libzcashlc copy into Apple's required versioned
# macOS framework layout after the package copy phase flattens symlinks.
# Destination-only: never mutate a package cache checkout.

set -euo pipefail

if [ -z "${TARGET_BUILD_DIR:-}" ] || [ -z "${FRAMEWORKS_FOLDER_PATH:-}" ]; then
  echo "error: TARGET_BUILD_DIR and FRAMEWORKS_FOLDER_PATH are required"
  exit 1
fi

framework="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/libzcashlc.framework"

# Archive installs into InstallationBuildProductsLocation/Applications, where
# there is no sibling flat framework. Debug/unit builds keep the donor beside
# the app under TARGET_BUILD_DIR. Prefer any donor that still has Headers.
resolve_donor() {
  local candidate
  for candidate in \
    "${TARGET_BUILD_DIR}/libzcashlc.framework" \
    "${BUILT_PRODUCTS_DIR:-}/libzcashlc.framework" \
    "${CONFIGURATION_BUILD_DIR:-}/libzcashlc.framework"
  do
    if [ -z "${candidate}" ] || [ "${candidate}" = "${framework}" ]; then
      continue
    fi
    if [ -d "${candidate}/Headers" ] || [ -d "${candidate}/Versions/A/Headers" ]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  for candidate in \
    "${TARGET_BUILD_DIR}/libzcashlc.framework" \
    "${BUILT_PRODUCTS_DIR:-}/libzcashlc.framework" \
    "${CONFIGURATION_BUILD_DIR:-}/libzcashlc.framework"
  do
    if [ -z "${candidate}" ] || [ "${candidate}" = "${framework}" ]; then
      continue
    fi
    if [ -d "${candidate}" ]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

donor=""
if donor="$(resolve_donor)"; then
  :
else
  donor=""
fi

if [ ! -d "${framework}" ]; then
  if [ -n "${donor}" ] && [ -d "${donor}" ]; then
    mkdir -p "$(dirname "${framework}")"
    cp -R "${donor}" "${framework}"
  else
    echo "error: embedded libzcashlc framework is missing at ${framework}"
    exit 1
  fi
fi

layout_complete() {
  [ -f "${framework}/Versions/Current/Resources/Info.plist" ] \
    && [ -e "${framework}/Versions/Current/libzcashlc" ] \
    && [ -d "${framework}/Versions/Current/Headers" ] \
    && [ -d "${framework}/Versions/Current/Modules" ]
}

if layout_complete; then
  echo "libzcashlc already uses the required versioned macOS framework layout"
  exit 0
fi

if [ -z "${donor}" ]; then
  echo "error: no libzcashlc donor framework found (checked TARGET_BUILD_DIR, BUILT_PRODUCTS_DIR, CONFIGURATION_BUILD_DIR)"
  exit 1
fi

# Recover from a half-repaired tree by reseeding flat files from the donor product.
seed_from_donor() {
  local name="$1"
  local donor_source=""
  if [ -e "${framework}/${name}" ] || [ -e "${framework}/Versions/A/${name}" ] \
    || [ -e "${framework}/Versions/A/Resources/${name}" ]; then
    return 0
  fi
  if [ -e "${donor}/${name}" ]; then
    donor_source="${donor}/${name}"
  elif [ -e "${donor}/Versions/A/${name}" ]; then
    donor_source="${donor}/Versions/A/${name}"
  elif [ -e "${donor}/Versions/A/Resources/${name}" ]; then
    donor_source="${donor}/Versions/A/Resources/${name}"
  else
    return 0
  fi
  cp -R "${donor_source}" "${framework}/${name}"
}

seed_from_donor libzcashlc
seed_from_donor Info.plist
seed_from_donor Headers
seed_from_donor Modules

mkdir -p "${framework}/Versions/A/Resources"

move_if_needed() {
  source_path="$1"
  destination_path="$2"
  if [ -e "${destination_path}" ]; then
    return
  fi
  if [ ! -e "${source_path}" ]; then
    echo "error: refusing to repair unexpected libzcashlc layout; missing ${source_path} (donor=${donor})"
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

if ! layout_complete; then
  echo "error: libzcashlc repair finished but layout is still incomplete at ${framework}"
  exit 1
fi

echo "Repaired embedded libzcashlc into a versioned macOS framework layout (donor=${donor})"
