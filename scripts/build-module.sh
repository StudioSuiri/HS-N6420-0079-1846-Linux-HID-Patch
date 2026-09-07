#!/usr/bin/env bash
#
# build-module.sh - Builds the patched usbhid module out-of-tree against the current kernel
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PATCH_FILE="${REPO_ROOT}/patches/0001-mayflash-0079-1846-usbhid-fix.patch"
BUILD_DIR="${REPO_ROOT}/build"
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

for tool in gcc make patch curl; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        echo "ERROR: Required build tool '${tool}' is not installed."
        echo "Please install build-essential and patch: sudo apt install build-essential patch"
        exit 1
    fi
done

# 2. Setup build directory
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# 3. Retrieve drivers/hid/usbhid source files matching current kernel
echo "[-] Preparing usbhid source files..."
BASE_URL="https://raw.githubusercontent.com/torvalds/linux/v$(echo "${KVER}" | cut -d'-' -f1)/drivers/hid/usbhid"

# Fallback to kernel headers or curl if git is not cloned
for f in hid-core.c hiddev.c hid-pidff.c hid-pidff.h usbhid.h; do
    if [ ! -f "${f}" ]; then
        echo "    Fetching ${f}..."
        if ! curl -sSL --fail "${BASE_URL}/${f}" -o "${f}"; then
            echo "    Fallback: Fetching from stable kernel tree..."
            curl -sSL --fail "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/hid/usbhid/${f}?h=v$(echo "${KVER}" | cut -d'.' -f1,2)" -o "${f}"
        fi
    fi
done

# 4. Create out-of-tree Makefile
cat << 'EOF' > Makefile
KDIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

obj-m += usbhid.o
usbhid-y := hid-core.o hiddev.o hid-pidff.o

default:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
EOF

# 5. Apply the patch
echo "[-] Applying patch 0001-mayflash-0079-1846-usbhid-fix.patch..."
# Reset hid-core.c if already patched
git checkout hid-core.c 2>/dev/null || true
if patch -p3 -N --dry-run < "${PATCH_FILE}" >/dev/null 2>&1; then
    patch -p3 < "${PATCH_FILE}"
    echo "    Patch applied successfully."
else
    if grep -q "0079:1846" hid-core.c; then
        echo "    Notice: hid-core.c already contains the 0079:1846 fix."
    else
        echo "ERROR: Failed to apply patch cleanly to hid-core.c."
        exit 1
    fi
fi

# 6. Build the module
echo "[-] Compiling module..."
make -C "${KSRC}" M="${BUILD_DIR}" clean
make -C "${KSRC}" M="${BUILD_DIR}" modules

if [ -f "${BUILD_DIR}/usbhid.ko" ]; then
    echo
    echo "========================================================"
    echo " SUCCESS: Module built at ${BUILD_DIR}/usbhid.ko"
    echo " Run './scripts/install-module.sh' to install it."
    echo "========================================================"
else
    echo "ERROR: Compilation failed, usbhid.ko was not created."
    exit 1
fi
