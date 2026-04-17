#!/usr/bin/env bash
set -euo pipefail

# Firmware fetch + unpack for Catalyst UI.
# Credits: Salvo Giangreco (UN1CA), SameerAlSahab, KrrishJaat (ReCoreUI), TopJohnWu.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/work}"
TOOL_DIR="${TOOL_DIR:-${ROOT_DIR}/tools}"

# shellcheck disable=SC1091
source "${WORK_DIR}/env.sh"

DEVICE_MODEL="${DEVICE_MODEL:-SM-A146B}"
CSC_REGION="${CSC_REGION:-INS}"

FW_DIR="${WORK_DIR}/firmware"
EXTRACT_DIR="${WORK_DIR}/extract"
RAW_DIR="${WORK_DIR}/raw"
SUPER_PART_DIR="${WORK_DIR}/super_parts"

mkdir -p "${FW_DIR}" "${EXTRACT_DIR}" "${RAW_DIR}" "${SUPER_PART_DIR}"

SAMLOADER="${TOOL_DIR}/bin/samloader"
AP_TAR="${FW_DIR}/AP.tar.md5"

# Fetch latest firmware version metadata and binaries.
FW_VER="$(${SAMLOADER} checkupdate "${DEVICE_MODEL}" "${CSC_REGION}" | tail -n1 | tr -d '\r')"
if [[ -z "${FW_VER}" ]]; then
  echo "Failed to resolve latest firmware for ${DEVICE_MODEL}/${CSC_REGION}" >&2
  exit 1
fi

echo "Resolved firmware: ${FW_VER}"

${SAMLOADER} download \
  --dev-model "${DEVICE_MODEL}" \
  --dev-region "${CSC_REGION}" \
  --fw-ver "${FW_VER}" \
  --out-file "${FW_DIR}/firmware.enc4"

${SAMLOADER} decrypt \
  --dev-model "${DEVICE_MODEL}" \
  --dev-region "${CSC_REGION}" \
  --fw-ver "${FW_VER}" \
  --enc-file "${FW_DIR}/firmware.enc4" \
  --out-file "${FW_DIR}/firmware.zip"

unzip -o "${FW_DIR}/firmware.zip" -d "${EXTRACT_DIR}"

# AP archive can include firmware hash suffixes.
AP_TAR_FOUND="$(find "${EXTRACT_DIR}" -maxdepth 1 -type f -name 'AP_*.tar.md5' | head -n1)"
if [[ -z "${AP_TAR_FOUND}" ]]; then
  echo "AP tar not found after firmware extraction" >&2
  exit 1
fi
cp "${AP_TAR_FOUND}" "${AP_TAR}"

tar -xf "${AP_TAR}" -C "${RAW_DIR}" \
  $(tar -tf "${AP_TAR}" | awk '/(super\.img\.lz4|boot\.img\.lz4|vbmeta\.img\.lz4)$/ {print}')

for img in super boot vbmeta; do
  lz4 -d -f "${RAW_DIR}/${img}.img.lz4" "${RAW_DIR}/${img}.img"
done

python3 "${TOOL_DIR}/lpunpack.py" "${RAW_DIR}/super.img" "${SUPER_PART_DIR}"

# Extract EROFS payloads to mountless rootfs dirs.
PARTITIONS=(system vendor product odm system_ext)
for part in "${PARTITIONS[@]}"; do
  if [[ -f "${SUPER_PART_DIR}/${part}.img" ]]; then
    mkdir -p "${WORK_DIR}/partitions/${part}"
    fsck.erofs --extract="${WORK_DIR}/partitions/${part}" "${SUPER_PART_DIR}/${part}.img"
  fi
done

echo "Phase 2 complete: partitions extracted in ${WORK_DIR}/partitions"
