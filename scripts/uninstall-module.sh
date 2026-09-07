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

if [ -f "${TARGET_DIR}/usbhid.ko.orig" ]; then
    echo "[-] Restoring ${TARGET_DIR}/usbhid.ko from .orig..."
    cp "${TARGET_DIR}/usbhid.ko.orig" "${TARGET_DIR}/usbhid.ko"
    RESTORED=1
fi

if [ -f "${TARGET_DIR}/usbhid.ko.zst.orig" ]; then
    echo "[-] Restoring ${TARGET_DIR}/usbhid.ko.zst from .orig..."
    cp "${TARGET_DIR}/usbhid.ko.zst.orig" "${TARGET_DIR}/usbhid.ko.zst"
    RESTORED=1
fi

if [ -f "${TARGET_DIR}/usbhid.ko.xz.orig" ]; then
    echo "[-] Restoring ${TARGET_DIR}/usbhid.ko.xz from .orig..."
    cp "${TARGET_DIR}/usbhid.ko.xz.orig" "${TARGET_DIR}/usbhid.ko.xz"
    RESTORED=1
fi

if [ "$RESTORED" -eq 0 ]; then
    echo "ERROR: No backup (.orig) files found in ${TARGET_DIR}/."
    echo "To restore the stock module, reinstall your kernel package, for example:"
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
