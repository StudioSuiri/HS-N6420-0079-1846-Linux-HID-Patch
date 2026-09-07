#!/usr/bin/env bash
#
# uninstall-module.sh - Restores the original stock usbhid module from backup
#

set -euo pipefail

KVER="$(uname -r)"
TARGET_DIR="/lib/modules/${KVER}/kernel/drivers/hid/usbhid"

echo "========================================================"
echo " Restoring Original Stock usbhid Module (${KVER})"
echo "========================================================"

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Root permissions required. Please run with sudo: sudo ./scripts/uninstall-module.sh"
    exit 1
fi

RESTORED=0

# Restore uncompressed .orig
if [ -f "${TARGET_DIR}/usbhid.ko.orig" ]; then
    echo "[-] Restoring ${TARGET_DIR}/usbhid.ko from usbhid.ko.orig..."
    cp -a "${TARGET_DIR}/usbhid.ko.orig" "${TARGET_DIR}/usbhid.ko"
    # If the system uses zstd, compress the restored module
    if [ -f "${TARGET_DIR}/usbhid.ko.zst" ] || command -v zstd >/dev/null 2>&1; then
        zstd -f -19 "${TARGET_DIR}/usbhid.ko" -o "${TARGET_DIR}/usbhid.ko.zst"
    fi
    RESTORED=1
fi

# Restore .zst.orig
if [ -f "${TARGET_DIR}/usbhid.ko.zst.orig" ]; then
    echo "[-] Restoring ${TARGET_DIR}/usbhid.ko.zst from usbhid.ko.zst.orig..."
    cp -a "${TARGET_DIR}/usbhid.ko.zst.orig" "${TARGET_DIR}/usbhid.ko.zst"
    RESTORED=1
fi

# Restore .xz.orig
if [ -f "${TARGET_DIR}/usbhid.ko.xz.orig" ]; then
    echo "[-] Restoring ${TARGET_DIR}/usbhid.ko.xz from usbhid.ko.xz.orig..."
    cp -a "${TARGET_DIR}/usbhid.ko.xz.orig" "${TARGET_DIR}/usbhid.ko.xz"
    RESTORED=1
fi

if [ "$RESTORED" -eq 0 ]; then
    echo "ERROR: No backup (.orig) files found in ${TARGET_DIR}/."
    echo "To restore the stock module from the package manager, reinstall:"
    echo "  sudo apt install --reinstall linux-modules-${KVER}"
    exit 1
fi

echo "[-] Updating module dependencies (depmod)..."
depmod -a

echo "[-] Reloading stock module in memory..."
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

echo "[-] Updating initramfs..."
if command -v update-initramfs >/dev/null 2>&1; then
    update-initramfs -u -k "${KVER}"
elif command -v dracut >/dev/null 2>&1; then
    dracut -f
fi

echo
echo "========================================================"
echo " Stock module successfully restored."
echo "========================================================"
