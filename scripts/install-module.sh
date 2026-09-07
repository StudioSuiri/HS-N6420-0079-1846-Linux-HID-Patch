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

ASSUME_YES=0
if [ "${1:-}" = "-y" ] || [ "${1:-}" = "--yes" ]; then
    ASSUME_YES=1
fi

echo "This script will:"
echo " 1. Back up the running kernel's stock usbhid driver in ${TARGET_DIR}/"
echo " 2. Install the locally built patched usbhid module into ${TARGET_DIR}/"
echo " 3. Run depmod -a to update module dependency maps"
echo " 4. Safely reload the usbhid kernel module in memory"
echo " 5. Update the initramfs to maintain persistence across reboots"
echo

if [ "$ASSUME_YES" -eq 0 ]; then
    read -r -p "Do you want to proceed with installing the module? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            echo "Proceeding with installation..."
            ;;
        *)
            echo "Installation cancelled by user."
            exit 0
            ;;
    esac
fi

if [ ! -f "${BUILD_DIR}/usbhid.ko" ]; then
    echo "ERROR: ${BUILD_DIR}/usbhid.ko not found."
    echo "Please run './scripts/build-module.sh' first."
    exit 1
fi

# 1. Back up original module if not already backed up
if [ ! -f "${TARGET_DIR}/usbhid.ko.orig" ] && [ ! -f "${TARGET_DIR}/usbhid.ko.zst.orig" ] && [ ! -f "${TARGET_DIR}/usbhid.ko.xz.orig" ]; then
    echo "[-] Creating backup of original stock module..."
    if [ -f "${TARGET_DIR}/usbhid.ko.zst" ]; then
        cp -a "${TARGET_DIR}/usbhid.ko.zst" "${TARGET_DIR}/usbhid.ko.zst.orig"
        echo "    Backup saved to ${TARGET_DIR}/usbhid.ko.zst.orig"
    elif [ -f "${TARGET_DIR}/usbhid.ko.xz" ]; then
        cp -a "${TARGET_DIR}/usbhid.ko.xz" "${TARGET_DIR}/usbhid.ko.xz.orig"
        echo "    Backup saved to ${TARGET_DIR}/usbhid.ko.xz.orig"
    elif [ -f "${TARGET_DIR}/usbhid.ko" ]; then
        cp -a "${TARGET_DIR}/usbhid.ko" "${TARGET_DIR}/usbhid.ko.orig"
        echo "    Backup saved to ${TARGET_DIR}/usbhid.ko.orig"
    fi
else
    echo "[-] Stock backup already safely preserved in ${TARGET_DIR}/ (skipping overwrite of backup)."
fi

# 2. Install patched module
echo "[-] Installing patched usbhid.ko..."
cp "${BUILD_DIR}/usbhid.ko" "${TARGET_DIR}/usbhid.ko"

# Compress if the distribution uses compressed modules (.zst or .xz)
if [ -f "${TARGET_DIR}/usbhid.ko.zst" ] || [ -f "${TARGET_DIR}/usbhid.ko.zst.orig" ] || command -v zstd >/dev/null 2>&1; then
    echo "    Compressing with zstd..."
    zstd -f -19 "${TARGET_DIR}/usbhid.ko" -o "${TARGET_DIR}/usbhid.ko.zst"
fi

if [ -f "${TARGET_DIR}/usbhid.ko.xz" ] || [ -f "${TARGET_DIR}/usbhid.ko.xz.orig" ]; then
    echo "    Compressing with xz..."
    xz -f -k "${TARGET_DIR}/usbhid.ko"
fi

# 3. Update module dependencies
echo "[-] Updating module dependencies (depmod)..."
depmod -a

# 4. Safely reload usbhid in memory
echo "[-] Reloading usbhid module..."
# Safely unbind all active HID devices to avoid kernel lockups
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

# Rebind USB HID devices
for dev in /sys/bus/usb/devices/*; do
    if [ -f "$dev/bInterfaceClass" ] && [ "$(cat "$dev/bInterfaceClass" 2>/dev/null)" = "03" ]; then
        base="$(basename "$dev")"
        echo "$base" > /sys/bus/usb/drivers/usbhid/bind 2>/dev/null || true
    fi
done

# 5. Update initramfs for reboot persistence
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
