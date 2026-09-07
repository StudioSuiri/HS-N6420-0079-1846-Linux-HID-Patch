# Troubleshooting Guide

This document covers common failure modes, symptoms, and diagnostic steps when working with the Mayflash GameCube Controller Adapter (VID:PID `0079:1846`) on Linux.

---

## 1. Original Symptom: Kernel usbhid Error -71

### dmesg Output:
```text
usbhid 1-9:1.0: can't add hid device: -71
usbhid 1-9:1.0: probe with driver usbhid failed with error -71
```

### Why it happens:
- The adapter stalls on standard USB HID class request `SET_IDLE` (`bRequest=0x0A`).
- When tested on modern xHCI (USB 3.0/3.1/3.2) controllers, this stall leaves the USB endpoint in an error state.
- The subsequent `GET_REPORT_DESCRIPTOR` request fails with protocol error `-EPROTO` (-71).
- Because descriptor reading fails, the kernel aborts device enumeration, and **no device nodes (`/dev/input/js*`, `/dev/input/event*`) are created**.

### Resolution:
Apply the patch in this repository (`patches/0001-mayflash-0079-1846-usbhid-fix.patch`), which skips `hid_set_idle()` for VID:PID `0079:1846` during initialization and post-reset paths.

---

## 2. Symptom: Only Ports 1 & 2 (or only 1 Port) Appear

### Cause:
The factory firmware descriptor provided by Mayflash in PC mode is only 198 bytes long, defining Report ID 1 and Report ID 2. However, the hardware micro-controller streams interrupt transfers across all 4 ports (Report IDs 1, 2, 3, and 4) via interrupt endpoint `0x81`.

### Resolution:
The patch dynamically expands the 198-byte descriptor to 396 bytes, duplicating the configuration for Report IDs 3 and 4. This guarantees that Linux registers all 4 ports (`js0` to `js3` and `event18` to `event21`).

---

## 3. Symptom: Inputs Stop Responding When Buttons Are Released

### Cause:
In some kernels, the USB HID driver suspends polling on interrupt endpoints if no keys/buttons are marked as currently pressed (autosuspend / power management).

### Resolution:
The patch sets `HID_QUIRK_ALWAYS_POLL` on `0079:1846`, ensuring the kernel continuously accepts interrupt URBs from endpoint `0x81`.

---

## 4. Mode Switch on Adapter (PC Mode vs. Wii U / Switch Mode)

The Mayflash adapter has a physical hardware switch on the back:
- **PC Mode:** Exposes USB VID:PID `0079:1846`. It acts as a standard HID device with 4 joysticks. **This is the mode fixed by this patch.**
- **Wii U / Switch Mode:** Exposes USB VID:PID `057e:0337`. It does not expose standard HID gamepads, but rather raw proprietary packets intended for the Dolphin emulator or Nintendo Switch via `libusb`.

If your adapter shows up as `057e:0337`, switch the physical toggle to **PC Mode** to use native Linux input gamepads.

---

## 5. Recovering Stock Kernel Driver

If you wish to remove the patch and restore the original distribution-supplied driver:
```bash
sudo ./scripts/uninstall-module.sh
```

Or reinstall the distro module package:
```bash
sudo apt install --reinstall linux-modules-$(uname -r)
```
