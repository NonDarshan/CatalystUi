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

install_package_best_effort() {
  local pkg="$1"
  if package_available "$pkg"; then
    ${SUDO} DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$pkg" && return 0
  fi
  return 1
}

install_first_available() {
  local installed=0
  for pkg in "$@"; do
    echo "[deps] Trying package candidate: $pkg"
    if install_package_best_effort "$pkg"; then
      installed=1
      break
    fi
  done

  if [[ "$installed" -ne 1 ]]; then
    echo "[deps] None of the package candidates installed successfully: $*" >&2
    return 1
  fi
}

echo "[deps] Updating apt indexes"
${SUDO} apt-get update -y

# Ensure optional Ubuntu component is enabled when available.
${SUDO} add-apt-repository -y universe >/dev/null 2>&1 || true
${SUDO} apt-get update -y

echo "[deps] Installing base apt packages"
for pkg in "${BASE_PACKAGES[@]}"; do
  if ! install_package_best_effort "$pkg"; then
    echo "[deps] Failed to install required package: $pkg" >&2
    exit 1
  fi
done

# 7z package naming differs across runners/distros. Try candidates in order.
install_first_available p7zip-full 7zip 7zip-standalone

# Optional codecs package might not exist on some mirrors; ignore failures.
install_package_best_effort p7zip-rar || true

if ! command -v 7z >/dev/null 2>&1 && command -v 7zz >/dev/null 2>&1; then
  echo "[deps] Creating 7z shim from 7zz"
  ${SUDO} ln -sf "$(command -v 7zz)" /usr/local/bin/7z
fi

echo "[deps] Upgrading pip and installing python tools"
python3 -m pip install --upgrade pip
python3 -m pip install --upgrade samloader

echo "[deps] Dependency setup complete"
