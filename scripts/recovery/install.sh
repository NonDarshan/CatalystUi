#!/sbin/sh
set -e

ZIP_ROOT="$(cd "$(dirname "$0")" && pwd)"

ui_print() {
  echo "ui_print $1"
  echo "ui_print"
}

ui_print "CatalystUi Installer"
ui_print "Mounting partitions..."

mount /system_root 2>/dev/null || true
mount /system 2>/dev/null || true
mount /product 2>/dev/null || true
mount /system_ext 2>/dev/null || true

ui_print "Extracting CatalystUi payload..."
cp -a "${ZIP_ROOT}/rom_payload/system/." /system/ 2>/dev/null || true
cp -a "${ZIP_ROOT}/rom_payload/product/." /product/ 2>/dev/null || true
cp -a "${ZIP_ROOT}/rom_payload/system_ext/." /system_ext/ 2>/dev/null || true

chmod -R 0644 /system/system/etc/catalystui_features.prop 2>/dev/null || true

if [ -x "${ZIP_ROOT}/patch_vbmeta.sh" ]; then
  ui_print "Applying vbmeta patch helper..."
  "${ZIP_ROOT}/patch_vbmeta.sh" || true
fi

ui_print "Done. Wipe dalvik/cache, then reboot."
exit 0
