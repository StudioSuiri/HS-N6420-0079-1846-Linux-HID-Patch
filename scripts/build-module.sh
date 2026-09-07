#!/usr/bin/env bash
#
# build-module.sh - Builds the patched usbhid module out-of-tree against the current kernel
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PATCH_FILE="${REPO_ROOT}/patches/0001-mayflash-0079-1846-usbhid-fix.patch"
BUILD_DIR="${REPO_ROOT}/build"
SRC_DIR="${REPO_ROOT}/src"
KVER="$(uname -r)"
KSRC="/lib/modules/${KVER}/build"

echo "========================================================"
echo " Building Patched usbhid Module for Kernel ${KVER}"
echo "========================================================"

# 1. Check prerequisites
echo "[-] Checking kernel build environment..."
if [ ! -d "${KSRC}" ]; then
    echo "ERROR: Kernel build headers not found at ${KSRC}."
    echo "Please install them via: sudo apt install linux-headers-${KVER}"
    exit 1
fi

for tool in gcc make patch; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        echo "ERROR: Required build tool '${tool}' is not installed."
        echo "Please install build-essential and patch: sudo apt install build-essential patch"
        exit 1
    fi
done

# 2. Setup clean build directory from local repository src/
echo "[-] Setting up build environment in ${BUILD_DIR}..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

cp -a "${SRC_DIR}"/* "${BUILD_DIR}/"
cd "${BUILD_DIR}"

# 3. Apply the patch
echo "[-] Applying patch $(basename "${PATCH_FILE}")..."
if patch -p4 -N --dry-run < "${PATCH_FILE}" >/dev/null 2>&1; then
    patch -p4 < "${PATCH_FILE}"
    echo "    Patch applied cleanly."
else
    if grep -q "0079:1846" hid-core.c; then
        echo "    Notice: hid-core.c already contains the 0079:1846 fix."
    else
        echo "ERROR: Failed to apply patch cleanly to hid-core.c."
        exit 1
    fi
fi

# 4. Build the module
echo "[-] Compiling module against ${KSRC}..."
make -C "${KSRC}" M="${BUILD_DIR}" clean
make -C "${KSRC}" M="${BUILD_DIR}" modules

if [ -f "${BUILD_DIR}/usbhid.ko" ]; then
    echo
    echo "========================================================"
    echo " SUCCESS: Module built at ${BUILD_DIR}/usbhid.ko"
    echo " Vermagic: $(modinfo -F vermagic "${BUILD_DIR}/usbhid.ko")"
    echo
    echo " Run 'sudo ./scripts/install-module.sh' to install it."
    echo "========================================================"
else
    echo "ERROR: Compilation failed, usbhid.ko was not created."
    exit 1
fi
