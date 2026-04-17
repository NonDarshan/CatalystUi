#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  SUDO="sudo"
else
  SUDO=""
fi

BASE_PACKAGES=(
  zip
  unzip
  lz4
  brotli
  simg2img
  e2fsprogs
  android-sdk-libsparse-utils
  python3
  python3-pip
  python3-venv
  curl
  ca-certificates
  file
  tar
  xz-utils
  jq
  xmlstarlet
)

package_available() {
  local pkg="$1"
  apt-cache show "$pkg" >/dev/null 2>&1
}

install_first_available() {
  local installed=0
  for pkg in "$@"; do
    if package_available "$pkg"; then
      echo "[deps] Installing package candidate: $pkg"
      ${SUDO} DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$pkg"
      installed=1
      break
    fi
  done

  if [[ "$installed" -ne 1 ]]; then
    echo "[deps] None of the package candidates are available: $*" >&2
    return 1
  fi
}

echo "[deps] Updating apt indexes"
${SUDO} apt-get update -y

echo "[deps] Installing base apt packages"
${SUDO} DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${BASE_PACKAGES[@]}"

# 7z package naming differs across runners/distros. Try candidates in order.
install_first_available p7zip-full 7zip

# Optional codecs package might not exist on some mirrors; ignore failures.
if package_available p7zip-rar; then
  ${SUDO} DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends p7zip-rar || true
fi

if ! command -v 7z >/dev/null 2>&1 && command -v 7zz >/dev/null 2>&1; then
  echo "[deps] Creating 7z shim from 7zz"
  ${SUDO} ln -sf "$(command -v 7zz)" /usr/local/bin/7z
fi

echo "[deps] Upgrading pip and installing python tools"
python3 -m pip install --upgrade pip
python3 -m pip install --upgrade samloader

echo "[deps] Dependency setup complete"
