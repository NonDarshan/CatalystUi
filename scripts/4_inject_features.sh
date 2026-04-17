#!/usr/bin/env bash
set -euo pipefail

# Catalyst UI feature injection logic.
# Credits: Salvo Giangreco (UN1CA), SameerAlSahab, KrrishJaat (ReCoreUI), TopJohnWu.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/work}"
ASSET_REPO_URL="${ASSET_REPO_URL:-}"

PART_ROOT="${WORK_DIR}/partitions"
ASSET_DIR="${WORK_DIR}/assets"
mkdir -p "${ASSET_DIR}"

FLOATING_FEATURE_FILE="$(find "${PART_ROOT}" -type f -name 'floating_feature.xml' | head -n1)"
CSC_FEATURE_FILE="$(find "${PART_ROOT}" -type f -name 'cscfeature.xml' | head -n1)"

if [[ -n "${ASSET_REPO_URL}" ]]; then
  if [[ "${ASSET_REPO_URL}" =~ \.git$ ]]; then
    git clone --depth=1 "${ASSET_REPO_URL}" "${ASSET_DIR}/repo"
  elif [[ "${ASSET_REPO_URL}" =~ \.zip($|\?) ]]; then
    curl -fsSL "${ASSET_REPO_URL}" -o "${ASSET_DIR}/assets.zip"
    unzip -o "${ASSET_DIR}/assets.zip" -d "${ASSET_DIR}/repo"
  else
    curl -fsSL "${ASSET_REPO_URL}" -o "${ASSET_DIR}/assets.tar"
    tar -xf "${ASSET_DIR}/assets.tar" -C "${ASSET_DIR}"
  fi
else
  echo "ASSET_REPO_URL is empty; continuing without remote asset injection"
fi

append_tag() {
  local file="$1"; shift
  local tag="$1"; shift
  grep -Fqx "$tag" "$file" || sed -i "s#</FeatureSet>#${tag}\n</FeatureSet>#" "$file"
}

if [[ -n "${FLOATING_FEATURE_FILE}" ]]; then
  append_tag "${FLOATING_FEATURE_FILE}" '<SEC_FLOATING_FEATURE_GRAPHICS_SUPPORT_3D_SURFACE_TRANSITION>true</SEC_FLOATING_FEATURE_GRAPHICS_SUPPORT_3D_SURFACE_TRANSITION>'
  append_tag "${FLOATING_FEATURE_FILE}" '<SEC_FLOATING_FEATURE_GRAPHICS_SUPPORT_CAPTURED_BLUR>true</SEC_FLOATING_FEATURE_GRAPHICS_SUPPORT_CAPTURED_BLUR>'
  append_tag "${FLOATING_FEATURE_FILE}" '<SEC_FLOATING_FEATURE_SYSTEMUI_CONFIG_EDGELIGHTING_FRAME_EFFECT>frame_effect_v3</SEC_FLOATING_FEATURE_SYSTEMUI_CONFIG_EDGELIGHTING_FRAME_EFFECT>'
  append_tag "${FLOATING_FEATURE_FILE}" '<SEC_FLOATING_FEATURE_AOD_CONFIG_CLOCK_TRANSITION>true</SEC_FLOATING_FEATURE_AOD_CONFIG_CLOCK_TRANSITION>'
fi

if [[ -n "${CSC_FEATURE_FILE}" ]]; then
  python3 - "$CSC_FEATURE_FILE" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8', errors='ignore')
entries = [
    '<CscFeature_SystemUI_SupportRealTimeNetworkSpeed>true</CscFeature_SystemUI_SupportRealTimeNetworkSpeed>',
    '<CscFeature_Common_SupportAppLock>true</CscFeature_Common_SupportAppLock>',
    '<CscFeature_VoiceCall_ConfigRecording>RecordingAllowed</CscFeature_VoiceCall_ConfigRecording>',
    '<CscFeature_Common_ConfigDualMessenger>all</CscFeature_Common_ConfigDualMessenger>',
    '<CscFeature_SystemUI_SupportDataUsageViewOnQuickPanel>true</CscFeature_SystemUI_SupportDataUsageViewOnQuickPanel>',
    '<CscFeature_SmartManager_ConfigSubFeatures>china</CscFeature_SmartManager_ConfigSubFeatures>',
]
for e in entries:
    if e not in text:
        text = text.replace('</FeatureSet>', f'{e}\n</FeatureSet>')
path.write_text(text, encoding='utf-8')
PY
fi

# build.prop spoof toggles (S25/S22 hybrid prop gates for flagship features)
while IFS= read -r -d '' prop_file; do
  grep -q '^ro.product.model=' "$prop_file" && sed -i 's/^ro.product.model=.*/ro.product.model=SM-S938B/' "$prop_file" || echo 'ro.product.model=SM-S938B' >> "$prop_file"
  grep -q '^ro.product.name=' "$prop_file" && sed -i 's/^ro.product.name=.*/ro.product.name=gts25xx/' "$prop_file" || echo 'ro.product.name=gts25xx' >> "$prop_file"
  grep -q '^ro.product.device=' "$prop_file" && sed -i 's/^ro.product.device=.*/ro.product.device=b0q/' "$prop_file" || echo 'ro.product.device=b0q' >> "$prop_file"
  grep -q '^ro.config.high_end_animation=' "$prop_file" && sed -i 's/^ro.config.high_end_animation=.*/ro.config.high_end_animation=true/' "$prop_file" || echo 'ro.config.high_end_animation=true' >> "$prop_file"
  grep -q '^ro.com.google.photos.quality=' "$prop_file" && sed -i 's/^ro.com.google.photos.quality=.*/ro.com.google.photos.quality=original/' "$prop_file" || echo 'ro.com.google.photos.quality=original' >> "$prop_file"
  grep -q '^ro.catalyst.feature.object_eraser=' "$prop_file" || echo 'ro.catalyst.feature.object_eraser=true' >> "$prop_file"
  grep -q '^ro.catalyst.feature.shadow_eraser=' "$prop_file" || echo 'ro.catalyst.feature.shadow_eraser=true' >> "$prop_file"
  grep -q '^ro.catalyst.feature.image_clipper=' "$prop_file" || echo 'ro.catalyst.feature.image_clipper=true' >> "$prop_file"
done < <(find "${PART_ROOT}" -type f -name build.prop -print0)

# Module and APK injection from downloaded assets
REPO_PAYLOAD_ROOT="$(find "${ASSET_DIR}" -mindepth 1 -maxdepth 3 -type d | head -n1 || true)"
if [[ -n "${REPO_PAYLOAD_ROOT}" ]]; then
  declare -A TARGETS=(
    [KnoxPatch]="${PART_ROOT}/system/priv-app/KnoxPatch"
    [BluetoothLibraryPatcher]="${PART_ROOT}/system/priv-app/BluetoothLibraryPatcher"
    [PlayIntegrityFix]="${PART_ROOT}/system/priv-app/PlayIntegrityFix"
    [TrickyStore]="${PART_ROOT}/system/priv-app/TrickyStore"
    [UN1CAOTA]="${PART_ROOT}/system/priv-app/UN1CAOTA"
    [FlipFont]="${PART_ROOT}/system/fonts/FlipFont"
  )

  for module in "${!TARGETS[@]}"; do
    src="$(find "${REPO_PAYLOAD_ROOT}" -type d -name "${module}" | head -n1 || true)"
    if [[ -n "${src}" ]]; then
      mkdir -p "${TARGETS[$module]}"
      cp -a "${src}/." "${TARGETS[$module]}/"
    fi
  done
fi

echo "Phase 4 complete: feature flags and asset injections processed"
