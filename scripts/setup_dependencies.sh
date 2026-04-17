#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  SUDO="sudo"
else
  SUDO=""
fi

APT_PACKAGES=(
  p7zip-full
  p7zip-rar
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

echo "[deps] Updating apt indexes"
${SUDO} apt-get update -y

echo "[deps] Installing apt packages"
${SUDO} DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${APT_PACKAGES[@]}"

echo "[deps] Upgrading pip and installing python tools"
python3 -m pip install --upgrade pip
python3 -m pip install --upgrade samloader

echo "[deps] Dependency setup complete"
