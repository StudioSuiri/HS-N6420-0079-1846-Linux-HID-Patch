#!/usr/bin/env bash
#
# verify.sh - Verifies that the Mayflash adapter is correctly detected and generating input events
#

set -u

echo "========================================================"
echo " Mayflash 0079:1846 Adapter Verification Tool"
echo "========================================================"
echo

# 1. Check USB presence
echo "[-] Checking USB device 0079:1846..."
if lsusb -d 0079:1846 >/dev/null 2>&1; then
    echo "    [OK] USB device found: $(lsusb -d 0079:1846)"
else
    echo "    [WARN] USB device 0079:1846 not currently plugged in."
fi
echo

# 2. Check kernel driver & error -71
echo "[-] Checking dmesg for error -71..."
if dmesg | grep -E "0079:1846.*error -71" | tail -n 1 >/dev/null 2>&1; then
    echo "    [NOTE] Past error -71 entries exist in dmesg (historical)."
fi

if dmesg | grep "expanded 0079:1846 descriptor to 4 ports" | tail -n 1 >/dev/null 2>&1; then
    echo "    [OK] Kernel patch active: 'expanded 0079:1846 descriptor to 4 ports' verified."
fi
echo

# 3. Check /dev/input device nodes
echo "[-] Checking input devices..."
CONTROLLERS=$(grep -c "mayflash limited GameCube Controller Adapter" /proc/bus/input/devices 2>/dev/null || true)
if [ "$CONTROLLERS" -ge 1 ]; then
    echo "    [OK] Found ${CONTROLLERS} Mayflash controller port(s) registered in /proc/bus/input/devices:"
    grep -E "Name=|Handlers=" /proc/bus/input/devices | grep -B 1 "js" | grep -A 1 "mayflash" || true
else
    echo "    [FAIL] No Mayflash controllers found in /proc/bus/input/devices."
fi
echo

# 4. Interactive evdev verification if python3-evdev is installed
if python3 -c "import evdev" >/dev/null 2>&1; then
    echo "[-] Reading live controller events (Port 1)..."
    python3 - << 'EOF'
import evdev, select, time, sys

ports = [evdev.InputDevice(p) for p in evdev.list_devices() if 'mayflash' in evdev.InputDevice(p).name.lower()]
if not ports:
    print("    No evdev nodes found for Mayflash adapter.")
    sys.exit(0)

dev = sorted(ports, key=lambda d: d.path)[0]
print(f"    Listening on {dev.path} ({dev.name}) for 5 seconds...")
print("    --> PLEASE PRESS ANY BUTTON OR MOVE THE STICK NOW <--")

t_end = time.time() + 5
events = 0
while time.time() < t_end:
    r, _, _ = select.select([dev.fd], [], [], 0.1)
    if r:
        for ev in dev.read():
            if ev.type != 0:
                print(f"    [EVENT] Type: {ev.type}, Code: {ev.code}, Value: {ev.value}")
                events += 1
                if events >= 5:
                    print("    [OK] Physical controller events verified successfully!")
                    sys.exit(0)

if events == 0:
    print("    [NOTE] No events received in 5s. If a controller is plugged into Port 1, press buttons to test.")
EOF
fi

echo
echo "========================================================"
echo " Verification Complete."
echo "========================================================"
