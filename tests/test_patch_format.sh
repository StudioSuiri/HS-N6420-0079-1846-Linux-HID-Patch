#!/usr/bin/env bash
#
# test_patch_format.sh - Automated validation of the patch file, scripts syntax, and security hygiene
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PATCH_FILE="${REPO_ROOT}/patches/0001-mayflash-0079-1846-usbhid-fix.patch"

echo "========================================================"
echo " Running Automated Repository & Patch Integrity Checks"
echo "========================================================"

# 1. Patch file existence
echo "[-] Checking patch file presence..."
if [ ! -f "${PATCH_FILE}" ]; then
    echo "FAIL: Patch file does not exist: ${PATCH_FILE}"
    exit 1
fi

# 2. Strict VID/PID presence
echo "[-] Validating target device ID (VID:PID 0079:1846)..."
if ! grep -q "0x0079" "${PATCH_FILE}" || ! grep -q "0x1846" "${PATCH_FILE}"; then
    echo "FAIL: Patch does not reference VID 0x0079 and PID 0x1846"
    exit 1
fi

# 3. Patch contents integrity
echo "[-] Validating kernel workaround logic in patch..."
if ! grep -q "skipping hid_set_idle for 0079:1846" "${PATCH_FILE}"; then
    echo "FAIL: Patch is missing the hid_set_idle skip logic"
    exit 1
fi

if ! grep -q "expanded 0079:1846 descriptor to 4 ports" "${PATCH_FILE}"; then
    echo "FAIL: Patch is missing the 4-port report descriptor expansion"
    exit 1
fi

if ! grep -q "HID_QUIRK_ALWAYS_POLL" "${PATCH_FILE}"; then
    echo "FAIL: Patch is missing HID_QUIRK_ALWAYS_POLL"
    exit 1
fi

# 4. Security: Check that no debug / diagnostic leak exists
echo "[-] Checking for diagnostic leakage..."
if grep -q "pkt_count" "${PATCH_FILE}"; then
    echo "FAIL: Temporary debug variable 'pkt_count' found in patch"
    exit 1
fi

# 5. Bash script syntax validation (bash -n)
echo "[-] Validating bash scripts syntax..."
for s in "${REPO_ROOT}"/scripts/*.sh "${REPO_ROOT}"/tests/*.sh; do
    if [ -f "$s" ]; then
        if ! bash -n "$s"; then
            echo "FAIL: Syntax error in script $s"
            exit 1
        fi
    fi
done

# 6. Security check: No binary artifacts, ROMs, or keys tracked
echo "[-] Checking for forbidden binary files or secrets in git..."
FORBIDDEN=$(find "${REPO_ROOT}" -not -path '*/.*' -type f \( -name "*.ko" -o -name "*.o" -o -name "*.z64" -o -name "*.n64" -o -name "*.bin" -o -name "*.id_rsa" -o -name "*.key" \) 2>/dev/null || true)
if [ -n "$FORBIDDEN" ]; then
    echo "FAIL: Forbidden binary/secret files found in tree: $FORBIDDEN"
    exit 1
fi

echo
echo "========================================================"
echo " PASS: All repository integrity & security checks passed!"
echo "========================================================"
exit 0
