#!/usr/bin/env bash
set -euo pipefail

# Rebuild EROFS images, super, vbmeta patch, and TWRP flashable zip.
# Credits: Salvo Giangreco (UN1CA), SameerAlSahab, KrrishJaat (ReCoreUI), TopJohnWu.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/work}"
TOOL_DIR="${TOOL_DIR:-${ROOT_DIR}/tools}"
OUT_DIR="${OUT_DIR:-${ROOT_DIR}/out}"
RELEASE_ZIP_NAME="${RELEASE_ZIP_NAME:-CatalystUI_Release.zip}"

PART_ROOT="${WORK_DIR}/partitions"
SUPER_PART_DIR="${WORK_DIR}/super_parts"
RAW_DIR="${WORK_DIR}/raw"
REPACK_DIR="${WORK_DIR}/repack"
ZIP_STAGING="${WORK_DIR}/zip_staging"

mkdir -p "${OUT_DIR}" "${REPACK_DIR}" "${ZIP_STAGING}"

PARTITIONS=(system vendor product odm system_ext)
IMAGE_ARGS=()
GROUP_SIZE=0

for p in "${PARTITIONS[@]}"; do
  src_dir="${PART_ROOT}/${p}"
  if [[ -d "${src_dir}" ]]; then
    out_img="${REPACK_DIR}/${p}.img"
    mkfs.erofs -zlz4hc,9 "${out_img}" "${src_dir}"
    img_size="$(stat -c '%s' "${out_img}")"
    GROUP_SIZE=$((GROUP_SIZE + img_size + 8 * 1024 * 1024))
    IMAGE_ARGS+=(
      --partition "${p}:readonly:${img_size}:catalyst_dynamic"
      --image "${p}=${out_img}"
    )
  fi
done

# Fallback to original geometry if available.
SUPER_SIZE="$(stat -c '%s' "${RAW_DIR}/super.img")"
METADATA_SIZE=$((4 * 1024 * 1024))

"${TOOL_DIR}/bin/lpmake" \
  --metadata-size "${METADATA_SIZE}" \
  --super-name super \
  --metadata-slots 2 \
  --device "super:${SUPER_SIZE}" \
  --group "catalyst_dynamic:${GROUP_SIZE}" \
  "${IMAGE_ARGS[@]}" \
  --sparse \
  --output "${REPACK_DIR}/super.img"

# Patch vbmeta with AVB disable flag 2 to prevent Samsung verification bootloops.
cp "${RAW_DIR}/vbmeta.img" "${REPACK_DIR}/vbmeta.img"
python3 "${TOOL_DIR}/avbtool.py" erase_footer --image "${REPACK_DIR}/vbmeta.img" || true
python3 "${TOOL_DIR}/avbtool.py" make_vbmeta_image \
  --output "${REPACK_DIR}/vbmeta.img" \
  --flags 2 \
  --padding_size 4096

# Keep boot.img from stock firmware unless another process mutates it.
cp "${RAW_DIR}/boot.img" "${REPACK_DIR}/boot.img"

rm -rf "${ZIP_STAGING:?}"/*
cp -a "${ROOT_DIR}/META-INF" "${ZIP_STAGING}/"
cp "${REPACK_DIR}/super.img" "${ZIP_STAGING}/"
cp "${REPACK_DIR}/boot.img" "${ZIP_STAGING}/"
cp "${REPACK_DIR}/vbmeta.img" "${ZIP_STAGING}/"

# Also include individual partition images for recoveries preferring raw flash targets.
for p in system vendor product odm system_ext; do
  [[ -f "${REPACK_DIR}/${p}.img" ]] && cp "${REPACK_DIR}/${p}.img" "${ZIP_STAGING}/"
done

pushd "${ZIP_STAGING}" >/dev/null
zip -r -1 "${OUT_DIR}/${RELEASE_ZIP_NAME}" .
popd >/dev/null

echo "Phase 5 complete: ${OUT_DIR}/${RELEASE_ZIP_NAME}"
