#!/usr/bin/env bash
set -euo pipefail

# Debloat and de-knox while preserving boot-critical Samsung services.
# Credits: Salvo Giangreco (UN1CA), SameerAlSahab, KrrishJaat (ReCoreUI), TopJohnWu.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/work}"

PART_ROOT="${WORK_DIR}/partitions"

declare -a REMOVE_PATHS=(
  # Carrier / telemetry / analytics
  "system/app/FBAppManager"
  "system/app/FBInstaller"
  "system/app/FBServices"
  "system/priv-app/OneDrive_Samsung_v3"
  "system/preload"
  "system/app/Upday"
  "system/app/LinkedIn_SamsungStub"
  "system/priv-app/SmartSuggestions"
  "system/priv-app/DiagMonAgent"
  "system/priv-app/SamsungVisitIn"
  "system/priv-app/NSDSWebApp"
  "system/priv-app/OMCAgent5"

  # Knox user-facing components to remove
  "system/priv-app/KnoxGuard"
  "system/priv-app/SecureFolder"
  "system/priv-app/KLMSAgent"
  "system/app/SecureFolderSetupPage"
)

for rel in "${REMOVE_PATHS[@]}"; do
  for part in system system_ext product vendor odm; do
    abs="${PART_ROOT}/${part}/${rel}"
    if [[ -e "${abs}" ]]; then
      rm -rf "${abs}"
    fi
  done
done

# Safety guard: keep boot-critical services expected by init rules.
CRITICAL_KEEP=(KnoxCore ContainerAgent BBCAgent)
for keep in "${CRITICAL_KEEP[@]}"; do
  if ! find "${PART_ROOT}" -type d -name "${keep}" | grep -q .; then
    echo "ERROR: critical package ${keep} missing. Aborting to avoid bootloop." >&2
    exit 1
  fi
done

echo "Phase 3 complete: debloat/de-knox done with critical services preserved"
