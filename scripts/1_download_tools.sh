#!/usr/bin/env bash
set -euo pipefail

# Catalyst UI kitchen bootstrap.
# Credits: Salvo Giangreco (UN1CA), SameerAlSahab, KrrishJaat (ReCoreUI), TopJohnWu.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOL_DIR="${TOOL_DIR:-${ROOT_DIR}/tools}"
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/work}"

mkdir -p "${TOOL_DIR}" "${WORK_DIR}"

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  bash \
  binutils \
  build-essential \
  ca-certificates \
  cmake \
  curl \
  cargo \
  git \
  jq \
  lz4 \
  erofs-utils \
  python3 \
  python3-pip \
  python3-venv \
  tar \
  unzip \
  xz-utils \
  zip

# Pull pre-compiled native Linux lpmake/lpdump from LineageOS 20.0.
# Using 'git clone' bypasses all 404 and raw-link download corruptions.
if [[ ! -x "${TOOL_DIR}/bin/lpmake" || ! -x "${TOOL_DIR}/bin/lpdump" ]]; then
  echo "📥 Fetching pre-compiled tools directly from LineageOS 20.0 tree..."
  git clone --depth=1 -b lineage-20.0 https://github.com/LineageOS/android_prebuilts_tools-lineage.git "${TOOL_DIR}/lineage-tools"
  
  mkdir -p "${TOOL_DIR}/bin"
  cp "${TOOL_DIR}/lineage-tools/linux-x86/bin/lpmake" "${TOOL_DIR}/bin/lpmake"
  cp "${TOOL_DIR}/lineage-tools/linux-x86/bin/lpdump" "${TOOL_DIR}/bin/lpdump"
  
  chmod +x "${TOOL_DIR}/bin/lpmake" "${TOOL_DIR}/bin/lpdump"
  
  # Clean up the 100MB+ repo to save workspace storage
  rm -rf "${TOOL_DIR}/lineage-tools" 
fi

# Build lpmake/lpdump natively (do not rely on mirrors).
if [[ ! -x "${TOOL_DIR}/bin/lpmake" || ! -x "${TOOL_DIR}/bin/lpdump" ]]; then
  git clone --depth=1 https://github.com/thka2016/lpunpack_and_lpmake_cmake.git "${TOOL_DIR}/lpunpack_and_lpmake_cmake"
  pushd "${TOOL_DIR}/lpunpack_and_lpmake_cmake" >/dev/null
  cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
  cmake --build build -- -j"$(nproc)"
  popd >/dev/null
  mkdir -p "${TOOL_DIR}/bin"
  cp "${TOOL_DIR}/lpunpack_and_lpmake_cmake/build/lpmake" "${TOOL_DIR}/bin/lpmake"
  cp "${TOOL_DIR}/lpunpack_and_lpmake_cmake/build/lpdump" "${TOOL_DIR}/bin/lpdump"
fi

# Pull avbtool.py from official AOSP googlesource (base64 text endpoint).
if [[ ! -f "${TOOL_DIR}/avbtool.py" ]]; then
  curl -fsSL \
    "https://android.googlesource.com/platform/external/avb/+/refs/heads/master/avbtool.py?format=TEXT" \
    | base64 --decode > "${TOOL_DIR}/avbtool.py"
  chmod +x "${TOOL_DIR}/avbtool.py"
fi

# Pull unix3dgforce lpunpack.py helper.
if [[ ! -f "${TOOL_DIR}/lpunpack.py" ]]; then
  curl -fsSL \
    "https://raw.githubusercontent.com/unix3dgforce/lpunpack/main/lpunpack.py" \
    -o "${TOOL_DIR}/lpunpack.py"
  chmod +x "${TOOL_DIR}/lpunpack.py"
fi

# Python helper deps
python3 -m pip install --user --upgrade pip

# Export local toolchain path for downstream scripts.
cat > "${WORK_DIR}/env.sh" <<ENVEOF
export ROOT_DIR="${ROOT_DIR}"
export TOOL_DIR="${TOOL_DIR}"
export WORK_DIR="${WORK_DIR}"
export PATH="${TOOL_DIR}/bin:\$PATH"
ENVEOF

echo "Phase 1 complete: tools available in ${TOOL_DIR}"
