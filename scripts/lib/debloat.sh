#!/usr/bin/env bash
set -euo pipefail

PAYLOAD_ROOT="$1"
PROFILE="${2:-heavy}"

SAFE_LIST=(
  "system/system/app/ARZone"
  "system/system/app/LinkToWindowsService"
  "system/system/app/Netflix_stub"
  "system/system/app/Facebook_stub"
  "product/app/Spotify"
  "product/priv-app/SmartTutor"
)

HEAVY_EXTRA=(
  "system/system/priv-app/GameOptimizer"
  "system/system/app/OneDrive_Samsung_v3"
  "system/system/app/SamsungTTS"
  "product/app/YouTube"
  "product/app/Facebook"
  "product/app/Netflix"
  "product/app/OfficeMobile_SamsungStub"
)

DEBLOAT_LIST=("${SAFE_LIST[@]}")
if [[ "${PROFILE}" == "heavy" ]]; then
  DEBLOAT_LIST+=("${HEAVY_EXTRA[@]}")
fi

echo "Using debloat profile: ${PROFILE}"
for rel in "${DEBLOAT_LIST[@]}"; do
  target="${PAYLOAD_ROOT}/${rel}"
  if [[ -e "${target}" ]]; then
    rm -rf "${target}"
    echo "Removed ${rel}"
  fi
done
