#!/sbin/sh
set -e

for bin in /system/bin/avbctl /vendor/bin/avbctl /sbin/avbctl; do
  if [ -x "$bin" ]; then
    "$bin" disable-verification || true
    "$bin" disable-verity || true
    exit 0
  fi
done

# Fallback only logs instruction when avbctl is not present.
echo "avbctl not found in recovery. Flash patched vbmeta manually if verification remains enabled."
exit 0
