#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${ROOT_DIR}/work"
OUT_DIR="${ROOT_DIR}/out"
LOG_DIR="${OUT_DIR}/logs"
TMP_DIR="${WORK_DIR}/tmp"
FIRMWARE_DIR="${WORK_DIR}/firmware"
UNPACK_DIR="${WORK_DIR}/unpack"
MOUNT_DIR="${WORK_DIR}/mount"
PAYLOAD_DIR="${ROOT_DIR}/rom_payload"

FIRMWARE_SOURCE="samloader"
FIRMWARE_URL=""
SAMLOADER_MODEL="SM-A146B"
SAMLOADER_REGION="INS"
SAMLOADER_VERSION="latest"
ROM_VERSION="v0.1-alpha"
APPLY_DEBLOAT="true"
DEBLOAT_PROFILE="heavy"
PATCH_VBMETA="true"
FORCE_FAST_CHARGE="true"
CUSTOM_WALLPAPER_DIR="${ROOT_DIR}/custom_wallpapers"

usage() {
  cat <<EOF
Usage: $0 [--firmware-source samloader|url] [--firmware-url URL] [--samloader-model MODEL] [--samloader-region REGION] [--samloader-version VERSION|latest] [--rom-version VERSION] [--apply-debloat true|false] [--debloat-profile safe|heavy] [--patch-vbmeta true|false] [--force-fast-charge true|false] [--custom-wallpaper-dir PATH]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --firmware-source) FIRMWARE_SOURCE="$2"; shift 2 ;;
    --firmware-url) FIRMWARE_URL="$2"; shift 2 ;;
    --samloader-model) SAMLOADER_MODEL="$2"; shift 2 ;;
    --samloader-region) SAMLOADER_REGION="$2"; shift 2 ;;
    --samloader-version) SAMLOADER_VERSION="$2"; shift 2 ;;
    --rom-version) ROM_VERSION="$2"; shift 2 ;;
    --apply-debloat) APPLY_DEBLOAT="$2"; shift 2 ;;
    --debloat-profile) DEBLOAT_PROFILE="$2"; shift 2 ;;
    --patch-vbmeta) PATCH_VBMETA="$2"; shift 2 ;;
    --force-fast-charge) FORCE_FAST_CHARGE="$2"; shift 2 ;;
    --custom-wallpaper-dir) CUSTOM_WALLPAPER_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "${FIRMWARE_SOURCE}" != "samloader" && "${FIRMWARE_SOURCE}" != "url" ]]; then
  echo "--firmware-source must be samloader or url" >&2
  exit 1
fi

if [[ "${FIRMWARE_SOURCE}" == "url" && -z "${FIRMWARE_URL}" ]]; then
  echo "--firmware-url is required when --firmware-source=url" >&2
  exit 1
fi

if [[ "${DEBLOAT_PROFILE}" != "safe" && "${DEBLOAT_PROFILE}" != "heavy" ]]; then
  echo "--debloat-profile must be safe or heavy" >&2
  exit 1
fi

mkdir -p "${WORK_DIR}" "${OUT_DIR}" "${LOG_DIR}" "${TMP_DIR}" "${FIRMWARE_DIR}" "${UNPACK_DIR}" "${MOUNT_DIR}"
rm -rf "${FIRMWARE_DIR:?}"/* "${UNPACK_DIR:?}"/* "${TMP_DIR:?}"/*

log() {
  printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"
}

require_toolchain() {
  local missing=0
  for tool in curl file tar unzip lz4 simg2img debugfs python3; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
      echo "Missing required tool: ${tool}" >&2
      missing=1
    fi
  done

  if [[ "${FIRMWARE_SOURCE}" == "samloader" ]] && ! command -v samloader >/dev/null 2>&1; then
    echo "Missing required tool for samloader mode: samloader" >&2
    missing=1
  fi

  if [[ "${missing}" -ne 0 ]]; then
    echo "Install dependencies first (run scripts/setup_dependencies.sh)." >&2
    exit 1
  fi
}

extract_firmware_archive() {
  local archive="$1"
  local file_type
  file_type="$(file -b "${archive}")"

  if [[ "${file_type}" == *"Zip archive"* ]]; then
    unzip -o "${archive}" -d "${FIRMWARE_DIR}" >"${LOG_DIR}/extract_firmware.log"
  elif [[ "${file_type}" == *"7-zip archive"* ]]; then
    python3 - <<PY7Z >"${LOG_DIR}/extract_firmware.log" 2>&1
from pathlib import Path
import py7zr
archive = Path(r"${archive}")
out = Path(r"${FIRMWARE_DIR}")
out.mkdir(parents=True, exist_ok=True)
with py7zr.SevenZipFile(archive, mode='r') as z:
    z.extractall(path=out)
print('Extracted', archive)
PY7Z
  else
    tar -xvf "${archive}" -C "${FIRMWARE_DIR}" >"${LOG_DIR}/extract_firmware.log"
  fi
}

download_firmware_url() {
  local archive="${FIRMWARE_DIR}/stock_firmware"
  log "Downloading stock firmware from direct URL"
  curl -L --retry 4 --retry-delay 5 -o "${archive}" "${FIRMWARE_URL}"
  extract_firmware_archive "${archive}"
}

download_firmware_samloader() {
  if ! command -v samloader >/dev/null 2>&1; then
    echo "samloader is not installed. Install with: python3 -m pip install samloader" >&2
    exit 1
  fi

  log "Fetching firmware metadata via samloader"
  local version
  if [[ "${SAMLOADER_VERSION}" == "latest" ]]; then
    version="$(samloader -m "${SAMLOADER_MODEL}" -r "${SAMLOADER_REGION}" checkupdate | tail -n 1 | tr -d '\r')"
  else
    version="${SAMLOADER_VERSION}"
  fi

  if [[ -z "${version}" ]]; then
    echo "Could not determine firmware version via samloader" >&2
    exit 1
  fi

  log "Using firmware version: ${version}"
  local enc_file="${FIRMWARE_DIR}/firmware.enc4"
  local zip_file="${FIRMWARE_DIR}/firmware.zip"

  samloader -m "${SAMLOADER_MODEL}" -r "${SAMLOADER_REGION}" download -v "${version}" -O "${enc_file}" >"${LOG_DIR}/samloader_download.log" 2>&1
  samloader decrypt -V "${version}" -i "${enc_file}" -o "${zip_file}" >"${LOG_DIR}/samloader_decrypt.log" 2>&1

  extract_firmware_archive "${zip_file}"
}

download_firmware() {
  if [[ "${FIRMWARE_SOURCE}" == "samloader" ]]; then
    download_firmware_samloader
  else
    download_firmware_url
  fi
}

extract_partition_tarballs() {
  log "Extracting AP package"
  local ap_file
  ap_file="$(find "${FIRMWARE_DIR}" -maxdepth 2 -type f -name 'AP_*' | head -n 1 || true)"

  if [[ -z "${ap_file}" ]]; then
    echo "Could not locate AP_* package in firmware." >&2
    exit 1
  fi

  mkdir -p "${UNPACK_DIR}/ap"
  tar -xvf "${ap_file}" -C "${UNPACK_DIR}/ap" >"${LOG_DIR}/extract_ap.log"

  find "${UNPACK_DIR}/ap" -maxdepth 1 -type f \( -name '*.img.lz4' -o -name '*.img' \) -print >"${LOG_DIR}/partitions_found.log"
}

convert_lz4_images() {
  log "Converting lz4 images"
  while IFS= read -r img; do
    if [[ "${img}" == *.lz4 ]]; then
      local dst="${img%.lz4}"
      lz4 -d "${img}" "${dst}" >/dev/null 2>&1
    fi
  done < <(find "${UNPACK_DIR}/ap" -maxdepth 1 -type f -name '*.img.lz4' | sort)
}

raw_extract_image_dir() {
  local image_path="$1"
  local out_path="$2"
  mkdir -p "${out_path}"

  if file "${image_path}" | grep -q 'Android sparse image'; then
    local raw_img="${TMP_DIR}/$(basename "${image_path}").raw"
    simg2img "${image_path}" "${raw_img}"
    debugfs -R "rdump / ${out_path}" "${raw_img}" >"${LOG_DIR}/debugfs_$(basename "${image_path}").log" 2>&1
  else
    debugfs -R "rdump / ${out_path}" "${image_path}" >"${LOG_DIR}/debugfs_$(basename "${image_path}").log" 2>&1
  fi
}

extract_partitions() {
  log "Extracting system partitions"
  rm -rf "${PAYLOAD_DIR}/system" "${PAYLOAD_DIR}/product" "${PAYLOAD_DIR}/system_ext"
  mkdir -p "${PAYLOAD_DIR}/system" "${PAYLOAD_DIR}/product" "${PAYLOAD_DIR}/system_ext"

  local system_img="${UNPACK_DIR}/ap/system.img"
  local product_img="${UNPACK_DIR}/ap/product.img"
  local system_ext_img="${UNPACK_DIR}/ap/system_ext.img"

  [[ -f "${system_img}" ]] && raw_extract_image_dir "${system_img}" "${PAYLOAD_DIR}/system"
  [[ -f "${product_img}" ]] && raw_extract_image_dir "${product_img}" "${PAYLOAD_DIR}/product"
  [[ -f "${system_ext_img}" ]] && raw_extract_image_dir "${system_ext_img}" "${PAYLOAD_DIR}/system_ext"
}

apply_rom_customizations() {
  log "Applying CatalystUi customizations"

  python3 "${ROOT_DIR}/scripts/lib/patch_prop.py" \
    --prop-file "${PAYLOAD_DIR}/system/system/build.prop" \
    --set ro.product.model="SM-S908B" \
    --set ro.product.system.model="SM-S908B" \
    --set ro.product.brand="samsung" \
    --set ro.catalystui.version="${ROM_VERSION}" \
    --set ro.catalystui.maintainer="CatalystUi Team" \
    --set ro.com.google.photos.pixel_backup=true \
    --set persist.sys.fflag.override.settings_enable_monitor_phantom_procs=false \
    --set persist.sys.sf.native_mode=2 \
    --set persist.sys.max_profiles=8 \
    --set ro.config.media_vol_steps=30 \
    --set persist.catalystui.live_blur_toggle=true \
    --set persist.catalystui.animation_toggle=true

  mkdir -p "${PAYLOAD_DIR}/system/system/etc"
  cp "${ROOT_DIR}/config/features.prop" "${PAYLOAD_DIR}/system/system/etc/catalystui_features.prop"

  mkdir -p "${PAYLOAD_DIR}/system/system/csc"
  cp "${ROOT_DIR}/config/others.xml" "${PAYLOAD_DIR}/system/system/csc/others.xml"

  if [[ "${APPLY_DEBLOAT}" == "true" ]]; then
    bash "${ROOT_DIR}/scripts/lib/debloat.sh" "${PAYLOAD_DIR}" "${DEBLOAT_PROFILE}" | tee "${LOG_DIR}/debloat.log"
  fi

  bash "${ROOT_DIR}/scripts/lib/thermal_profile.sh" "${PAYLOAD_DIR}" | tee "${LOG_DIR}/thermal_tuning.log"

  if [[ "${FORCE_FAST_CHARGE}" == "true" ]]; then
    bash "${ROOT_DIR}/scripts/lib/fast_charging.sh" "${PAYLOAD_DIR}" | tee "${LOG_DIR}/fast_charging.log"
  fi

  bash "${ROOT_DIR}/scripts/lib/wallpaper_pack.sh" "${PAYLOAD_DIR}" "${CUSTOM_WALLPAPER_DIR}" | tee "${LOG_DIR}/wallpaper.log"
}

stage_installer_assets() {
  log "Staging installer assets"
  rm -rf "${WORK_DIR}/ziproot"
  mkdir -p "${WORK_DIR}/ziproot"

  cp -r "${ROOT_DIR}/META-INF" "${WORK_DIR}/ziproot/"
  cp -r "${PAYLOAD_DIR}" "${WORK_DIR}/ziproot/rom_payload"
  cp "${ROOT_DIR}/scripts/recovery/install.sh" "${WORK_DIR}/ziproot/install.sh"
  chmod +x "${WORK_DIR}/ziproot/install.sh"

  if [[ "${PATCH_VBMETA}" == "true" ]]; then
    cp "${ROOT_DIR}/scripts/recovery/patch_vbmeta.sh" "${WORK_DIR}/ziproot/patch_vbmeta.sh"
    chmod +x "${WORK_DIR}/ziproot/patch_vbmeta.sh"
  fi
}

build_flashable_zip() {
  log "Packing flashable zip"
  local zip_name="CatalystUi_${ROM_VERSION}_SM-A146B.zip"
  (
    cd "${WORK_DIR}/ziproot"
    zip -r9 "${OUT_DIR}/${zip_name}" .
  ) >"${LOG_DIR}/zip.log"

  sha256sum "${OUT_DIR}/${zip_name}" | tee "${OUT_DIR}/${zip_name}.sha256"
  log "Build complete: ${OUT_DIR}/${zip_name}"
}

main() {
  require_toolchain
  download_firmware
  extract_partition_tarballs
  convert_lz4_images
  extract_partitions
  apply_rom_customizations
  stage_installer_assets
  build_flashable_zip
}

main "$@"
