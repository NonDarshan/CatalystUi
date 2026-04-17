#!/usr/bin/env bash
set -euo pipefail

PAYLOAD_ROOT="$1"
INIT_DIR="${PAYLOAD_ROOT}/system/system/etc/init"
BIN_DIR="${PAYLOAD_ROOT}/system/system/bin"

mkdir -p "${INIT_DIR}" "${BIN_DIR}"

cat > "${BIN_DIR}/catalyst_charge.sh" <<'EOF'
#!/system/bin/sh
# Best-effort fast charging enforcement. Nodes differ by kernel/vendor.
for node in \
  /sys/class/power_supply/battery/constant_charge_current_max \
  /sys/class/power_supply/battery/input_current_limit \
  /sys/class/power_supply/battery/fast_charge_current \
  /sys/class/power_supply/usb/current_max; do
  if [ -e "$node" ]; then
    chmod 0664 "$node" 2>/dev/null || true
    echo 9000000 > "$node" 2>/dev/null || true
  fi
done

for node in /sys/class/power_supply/battery/store_mode /sys/class/power_supply/battery/batt_slate_mode; do
  if [ -e "$node" ]; then
    echo 0 > "$node" 2>/dev/null || true
  fi
done
EOF
chmod 0755 "${BIN_DIR}/catalyst_charge.sh"

cat > "${INIT_DIR}/init.catalystui.charging.rc" <<'EOF'
on post-fs-data
    start catalyst_charge

service catalyst_charge /system/bin/sh /system/bin/catalyst_charge.sh
    class late_start
    user root
    group root system
    oneshot
EOF

echo "Injected fast charging service and init trigger"
