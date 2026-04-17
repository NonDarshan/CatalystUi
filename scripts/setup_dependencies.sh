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

install_package() {
  local pkg="$1"
  if package_available "$pkg"; then
    ${SUDO} DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$pkg"
    return 0
  fi
  return 1
}

echo "[deps] Updating apt indexes"
${SUDO} apt-get update -y
${SUDO} add-apt-repository -y universe >/dev/null 2>&1 || true
${SUDO} apt-get update -y

echo "[deps] Installing base apt packages"
for pkg in "${BASE_PACKAGES[@]}"; do
  if ! install_package "$pkg"; then
    echo "[deps] Failed to install required package: $pkg" >&2
    exit 1
  fi
done

# simg2img may be in different packages across images.
if ! command -v simg2img >/dev/null 2>&1; then
  install_package simg2img || true
fi
if ! command -v simg2img >/dev/null 2>&1; then
  echo "[deps] simg2img binary is missing after install attempts" >&2
  exit 1
fi

echo "[deps] Installing python tools"
python3 -m pip install --upgrade pip
python3 -m pip install --upgrade samloader py7zr

echo "[deps] Dependency setup complete"
