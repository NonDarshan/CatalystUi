#!/usr/bin/env bash
set -euo pipefail

PAYLOAD_ROOT="$1"
THERMAL_JSON="${PAYLOAD_ROOT}/vendor/etc/thermal-engine.conf"
mkdir -p "$(dirname "${THERMAL_JSON}")"

cat > "${THERMAL_JSON}" <<'EOF'
# CatalystUi balanced thermal profile
# WARNING: removing thermal limits entirely can damage hardware.
# This profile relaxes throttling instead of fully disabling protection.
[THROTTLING-NOTIFY]
sensor cpu
thresholds 78 84 90
actions cpu+gpu+charging

[CHARGING]
max_current_ma 2300
suspend_threshold 46
resume_threshold 43
EOF

echo "Applied balanced thermal profile to vendor/etc/thermal-engine.conf"
