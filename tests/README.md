# Automated Tests for Mayflash Kernel Patch Repository

This directory contains sanity and automated verification checks that validate the repository's patch and build tools.

---

## Running the Tests

To run the test suite:
```bash
./tests/test_patch_format.sh
```

---

## Test Cases

1. **`test_patch_format.sh`**:
   - Validates that the patch file exists and follows standard unified diff syntax.
   - Verifies target vendor ID `0079` and product ID `1846` are present in the patch.
   - Checks that all 3 critical fixes (`hid_set_idle`, `396` byte descriptor expansion, and `HID_QUIRK_ALWAYS_POLL`) are preserved.
   - Confirms that temporary debug printfs (e.g. `pkt_count`) were excluded from the release patch.

> **Note on Hardware Testing:**
> Physical hardware interaction (such as button presses and axis events) cannot be automated in CI environments without physical USB adapters attached. To verify live hardware, use the interactive `./scripts/verify.sh` tool on the target machine.
