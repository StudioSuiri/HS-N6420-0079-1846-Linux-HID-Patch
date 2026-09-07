#!/usr/bin/env bash
#
# install-module.sh - Installs the patched usbhid module with backup and rollback capability
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
KVER="$(uname -r)"
TARGET_DIR="/lib/modules/${KVER}/kernel/drivers/hid/usbhid"

echo "========================================================"
echo " Installing Patched usbhid Module (${KVER})"
echo "========================================================"

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Root permissions required. Please run with sudo: sudo ./scripts/install-module.sh"
    exit 1
fi

if [ ! -f "${BUILD_DIR}/usbhid.ko" ]; then
    echo "ERROR: ${BUILD_DIR}/usbhid.ko not found."
    echo "Please run './scripts/build-module.sh' first."
    exit 1
fi

# 1. Back up original module if not already backed up
if [ ! -f "${TARGET_DIR}/usbhid.ko.orig" ]; then
    echo "[-] Backing up original stock module..."
    if [ -f "${TARGET_DIR}/usbhid.ko.zst" ]; then
        cp "${TARGET_DIR}/usbhid.ko.zst" "${TARGET_DIR}/usbhid.ko.zst.orig"
    elif [ -f "${TARGET_DIR}/usbhid.ko.xz" ]; then
        cp "${TARGET_DIR}/usbhid.ko.xz" "${TARGET_DIR}/usbhid.ko.xz.orig"
    elif [ -f "${TARGET_DIR}/usbhid.ko" ]; then
        cp "${TARGET_DIR}/usbhid.ko" "${TARGET_DIR}/usbhid.ko.orig"
    fi
    echo "    Backup saved to ${TARGET_DIR}/"
else
    echo "[-] Original backup already exists at ${TARGET_DIR}/usbhid.ko.orig."
fi

# 2. Install patched module
echo "[-] Installing patched usbhid.ko..."
cp "${BUILD_DIR}/usbhid.ko" "${TARGET_DIR}/usbhid.ko"

# Compress if the distribution uses compressed modules
if [ -f "${TARGET_DIR}/usbhid.ko.zst" ] || command -v zstd >/dev/null 2>&1; then
    echo "    Compressing with zstd..."
    zstd -f -19 "${TARGET_DIR}/usbhid.ko" -o "${TARGET_DIR}/usbhid.ko.zst"
fi

# 3. Update module dependencies
echo "[-] Updating module dependencies (depmod)..."
depmod -a

# 4. Reload module live if requested or safe
echo "[-] Reloading usbhid module in memory..."
# Unbind devices to prevent hang on rmmod
for dev in /sys/bus/usb/drivers/usbhid/*:*; do
    if [ -e "$dev" ]; then
        base="$(basename "$dev")"
        echo "$base" > /sys/bus/usb/drivers/usbhid/unbind 2>/dev/null || true
    fi
done
sleep 0.5
rmmod usbhid 2>/dev/null || true
sleep 0.5
modprobe usbhid
sleep 0.5

# Rebind USB devices
for dev in /sys/bus/usb/devices/*; do
    if [ -f "$dev/bInterfaceClass" ] && [ "$(cat "$dev/bInterfaceClass" 2>/dev/null)" = "03" ]; then
        base="$(basename "$dev")"
        echo "$base" > /sys/bus/usb/drivers/usbhid/bind 2>/dev/null || true
    fi
done

echo "[-] Updating initramfs for persistence across reboots..."
if command -v update-initramfs >/dev/null 2>&1; then
    update-initramfs -u -k "${KVER}"
elif command -v dracut >/dev/null 2>&1; then
    dracut -f
fi

echo
echo "========================================================"
echo " Installation Complete!"
echo " Please run './scripts/verify.sh' to verify device recognition."
echo "========================================================"
