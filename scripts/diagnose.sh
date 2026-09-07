#!/usr/bin/env bash
#
# diagnose.sh - Read-only diagnostic collector for Mayflash 0079:1846 adapter
# This script NEVER modifies the system.
#

set -u

echo "========================================================"
echo " Mayflash 0079:1846 GameCube Adapter Diagnostic Collector"
echo "========================================================"
echo

echo "[-] System Information:"
echo "    Kernel: $(uname -r)"
echo "    Architecture: $(uname -m)"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "    Distribution: ${PRETTY_NAME:-$NAME $VERSION}"
fi
echo

echo "[-] USB Hardware Detection (VID:PID 0079:1846):"
if command -v lsusb >/dev/null 2>&1; then
    lsusb -d 0079:1846 || echo "    Device 0079:1846 NOT found in lsusb."
else
    echo "    lsusb command not available."
fi
echo

echo "[-] Kernel Modules Status:"
lsmod | grep -E "usbhid|hid_mf|hid" || echo "    No relevant HID modules loaded."
echo

echo "[-] Module Alias Check for 0079:1846:"
grep -iE "0079.*1846|1846.*0079" "/lib/modules/$(uname -r)/modules.alias" 2>/dev/null || echo "    No alias match found."
echo

echo "[-] Recent dmesg entries related to USB and HID:"
if command -v dmesg >/dev/null 2>&1; then
    dmesg | grep -iE "0079:1846|can't add hid device|usbhid.*failed|mayflash" | tail -n 25 || true
fi
echo

echo "[-] Input Devices (/proc/bus/input/devices):"
if [ -f /proc/bus/input/devices ]; then
    grep -A 10 -i "mayflash" /proc/bus/input/devices || echo "    No Mayflash adapter listed in /proc/bus/input/devices."
else
    echo "    /proc/bus/input/devices not available."
fi
echo

echo "[-] /dev/input device nodes:"
ls -l /dev/input/by-id/ /dev/input/js* 2>/dev/null || echo "    No joystick devices found in /dev/input."
echo

echo "[-] SDL2 Joystick enumeration (if tools available):"
if command -v sdl2-jstest >/dev/null 2>&1; then
    sdl2-jstest --list || true
else
    echo "    sdl2-jstest not installed (optional, test with apt install joystick)."
fi

echo
echo "========================================================"
echo " Diagnostic collection complete."
echo "========================================================"
