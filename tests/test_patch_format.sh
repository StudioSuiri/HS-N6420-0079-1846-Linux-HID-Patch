#!/usr/bin/env bash
#
# test_patch_format.sh - Automated sanity validation of the patch file
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PATCH_FILE="${REPO_ROOT}/patches/0001-mayflash-0079-1846-usbhid-fix.patch"

echo "Running Patch Integrity Checks..."

# 1. Existence check
if [ ! -f "${PATCH_FILE}" ]; then
    echo "FAIL: Patch file does not exist: ${PATCH_FILE}"
    exit 1
fi

# 2. Check VID and PID
if ! grep -q "0x0079" "${PATCH_FILE}" || ! grep -q "0x1846" "${PATCH_FILE}"; then
    echo "FAIL: Patch does not reference VID 0x0079 and PID 0x1846"
    exit 1
fi

# 3. Check for skipping hid_set_idle
if ! grep -q "skipping hid_set_idle for 0079:1846" "${PATCH_FILE}"; then
    echo "FAIL: Patch is missing the hid_set_idle skip logic"
    exit 1
fi

# 4. Check for 396 bytes 4-port expansion
if ! grep -q "expanded 0079:1846 descriptor to 4 ports" "${PATCH_FILE}"; then
    echo "FAIL: Patch is missing the 4-port report descriptor expansion"
    exit 1
fi

# 5. Check for ALWAYS_POLL quirk
if ! grep -q "HID_QUIRK_ALWAYS_POLL" "${PATCH_FILE}"; then
    echo "FAIL: Patch is missing HID_QUIRK_ALWAYS_POLL"
    exit 1
fi

# 6. Ensure no temporary diagnostic code leaked in
if grep -q "pkt_count" "${PATCH_FILE}"; then
    echo "FAIL: Temporary debug variable 'pkt_count' found in patch"
    exit 1
fi

echo "PASS: All patch formatting and content checks passed!"
exit 0
