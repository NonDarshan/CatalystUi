#!/usr/bin/env bash
set -euo pipefail

PAYLOAD_ROOT="$1"
WALLPAPER_SRC_DIR="$2"

TARGET_DIR="${PAYLOAD_ROOT}/product/media/wallpaper"
mkdir -p "${TARGET_DIR}"

src_file=""
if [[ -d "${WALLPAPER_SRC_DIR}" ]]; then
  src_file="$(find "${WALLPAPER_SRC_DIR}" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | head -n 1 || true)"
fi

if [[ -n "${src_file}" ]]; then
  cp "${src_file}" "${TARGET_DIR}/default_wallpaper_001.jpg"
  cp "${src_file}" "${TARGET_DIR}/default_wallpaper.jpg"
  echo "Custom wallpaper applied from ${src_file}"
else
  echo "No custom wallpaper found in ${WALLPAPER_SRC_DIR}; keeping stock wallpaper assets"
fi
