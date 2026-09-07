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

ASSUME_YES=0
if [ "${1:-}" = "-y" ] || [ "${1:-}" = "--yes" ]; then
    ASSUME_YES=1
fi

echo "This script will:"
echo " 1. Restore the original stock usbhid module from backup (.orig) in ${TARGET_DIR}/"
echo " 2. Run depmod -a to refresh module dependency maps"
echo " 3. Safely reload the stock usbhid module into memory"
echo " 4. Update the initramfs to persist stock configuration across reboots"
echo

if [ "$ASSUME_YES" -eq 0 ]; then
    read -r -p "Do you want to proceed with restoring the stock driver? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            echo "Proceeding with rollback..."
            ;;
        *)
            echo "Rollback cancelled by user."
            exit 0
            ;;
    esac
fi

# 1. Check for backups and perform restoration
BACKUP_FOUND=0

if [ -f "${TARGET_DIR}/usbhid.ko.zst.orig" ]; then
    echo "[-] Found backup ${TARGET_DIR}/usbhid.ko.zst.orig"
    echo "    Cleaning any active patched variants..."
    rm -f "${TARGET_DIR}/usbhid.ko" "${TARGET_DIR}/usbhid.ko.zst" "${TARGET_DIR}/usbhid.ko.xz"
    echo "    Restoring original stock module to ${TARGET_DIR}/usbhid.ko.zst..."
    cp -a "${TARGET_DIR}/usbhid.ko.zst.orig" "${TARGET_DIR}/usbhid.ko.zst"
    BACKUP_FOUND=1
elif [ -f "${TARGET_DIR}/usbhid.ko.xz.orig" ]; then
    echo "[-] Found backup ${TARGET_DIR}/usbhid.ko.xz.orig"
    echo "    Cleaning any active patched variants..."
    rm -f "${TARGET_DIR}/usbhid.ko" "${TARGET_DIR}/usbhid.ko.zst" "${TARGET_DIR}/usbhid.ko.xz"
    echo "    Restoring original stock module to ${TARGET_DIR}/usbhid.ko.xz..."
    cp -a "${TARGET_DIR}/usbhid.ko.xz.orig" "${TARGET_DIR}/usbhid.ko.xz"
    BACKUP_FOUND=1
elif [ -f "${TARGET_DIR}/usbhid.ko.orig" ]; then
    echo "[-] Found backup ${TARGET_DIR}/usbhid.ko.orig"
    echo "    Cleaning any active patched variants..."
    rm -f "${TARGET_DIR}/usbhid.ko" "${TARGET_DIR}/usbhid.ko.zst" "${TARGET_DIR}/usbhid.ko.xz"
    echo "    Restoring original stock module to ${TARGET_DIR}/usbhid.ko..."
    cp -a "${TARGET_DIR}/usbhid.ko.orig" "${TARGET_DIR}/usbhid.ko"
    # If the system had compressed modules, compress the restored module appropriately
    if command -v zstd >/dev/null 2>&1; then
        zstd -f -19 "${TARGET_DIR}/usbhid.ko" -o "${TARGET_DIR}/usbhid.ko.zst"
        rm -f "${TARGET_DIR}/usbhid.ko"
    fi
    BACKUP_FOUND=1
fi

if [ "$BACKUP_FOUND" -eq 0 ]; then
    echo "ERROR: No backup (.orig) files found in ${TARGET_DIR}/."
    echo "To restore the stock module from the package manager, reinstall:"
    echo "  sudo apt install --reinstall linux-modules-${KVER}"
    exit 1
fi

echo "[-] Updating module dependencies (depmod)..."
depmod -a

echo "[-] Attempting safe reload of stock usbhid in memory..."
if lsmod | grep -q "^usbhid"; then
    for dev in /sys/bus/usb/drivers/usbhid/*:*; do
        if [ -e "$dev" ]; then
            base="$(basename "$dev")"
            echo "$base" > /sys/bus/usb/drivers/usbhid/unbind 2>/dev/null || true
        fi
    done
    sleep 0.5

    if rmmod usbhid 2>/dev/null; then
        sleep 0.5
        if modprobe usbhid; then
            echo "    [OK] Stock usbhid module successfully reloaded in memory."
        fi
    else
        echo "    [NOTE] usbhid module is in use. Skipping in-memory unload to protect active input."
        echo "    A system reboot will load the restored stock module."
    fi

    for dev in /sys/bus/usb/devices/*; do
        if [ -f "$dev/bInterfaceClass" ] && [ "$(cat "$dev/bInterfaceClass" 2>/dev/null)" = "03" ]; then
            base="$(basename "$dev")"
            echo "$base" > /sys/bus/usb/drivers/usbhid/bind 2>/dev/null || true
        fi
    done
else
    modprobe usbhid || true
fi

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
