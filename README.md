# Mayflash 0079:1846 Linux HID Fix

This repository documents and packages a kernel-level workaround for the Mayflash / DragonRise `0079:1846` GameCube Controller Adapter, which can fail during HID initialization on modern Linux systems with `usbhid` error `-71`.

---

## 1. Overview & Problem Description

When connecting a Mayflash 4-port GameCube Controller Adapter in **PC Mode** (or an N64 controller via GameCube-to-N64 adapter), modern Linux kernels fail to enumerate the device as an input controller.

### Affected Hardware & USB Identification
* **USB VID:PID:** `0079:1846`
* **Manufacturer:** `mayflash limited`
* **Product:** `GameCube Controller Adapter`
* **Physical Mode:** PC Mode (hardware switch set to "PC")
* **Tested Kernel:** Ubuntu 24.04 / Linux Mint 22.3 with kernel `6.14.0-37-generic` (x86_64) on AMD xHCI Host Controller

### Original Symptoms & Failure Logs
Although `lsusb` detects the USB device:
```text
Bus 001 Device 005: ID 0079:1846 DragonRise Inc. GameCube Controller Adapter
```

The kernel HID subsystem aborts probing and `dmesg` repeatedly logs:
```text
usbhid 1-9:1.0: can't add hid device: -71
usbhid 1-9:1.0: probe with driver usbhid failed with error -71
```

**Result before the fix:**
* No controller entry appears in `/proc/bus/input/devices`.
* No `/dev/input/js*` or `/dev/input/event*` nodes are created for the adapter.
* Emulators (such as Mupen64Plus, Dolphin, RetroArch) cannot see or use the physical controller natively.

---

## 2. Root Cause Analysis

### Why does error -71 occur?
1. **The `SET_IDLE` Stall:** During `usbhid_parse()`, standard Linux HID driver initialization calls `hid_set_idle(dev, ifnum, 0, 0)` (`bRequest=0x0A`). The Mayflash firmware does not handle this class request properly and returns a stall / overflow (`-EOVERFLOW`).
2. **xHCI Protocol Failure:** On modern USB 3.x xHCI host controllers, this stall leaves the USB interface pipe in an error state. When `usbhid` immediately follows up with `hid_get_class_descriptor()` (`GET_REPORT_DESCRIPTOR`), the transaction fails with USB protocol error `-EPROTO` (**-71**).
3. **Incomplete Firmware Report Descriptor:** The factory descriptor stored in the adapter firmware is only 198 bytes long, defining only Report IDs 1 and 2, even though the hardware continuously transmits 10-byte packets across all 4 ports (Report IDs 1, 2, 3, and 4) on interrupt endpoint `0x81`.
4. **Endpoint Polling Drops:** Without `HID_QUIRK_ALWAYS_POLL`, kernels can halt interrupt polling when no keys are considered pressed, causing inputs to stop updating.

### Why was `hid-mf` insufficient?
The stock Linux kernel already contains the `hid_mf` module and a matching alias for `0079:1846`. However, `hid_mf` only handles **force feedback / rumble effects** *after* the USB HID device has already been successfully probed and claimed by `usbhid`. Because `usbhid` failed at the USB class layer with error -71, `hid_mf` was never called.

---

## 3. What the Patch Changes

The minimal patch (`patches/0001-mayflash-0079-1846-usbhid-fix.patch`) modifies `drivers/hid/usbhid/hid-core.c`:

1. **Skips `hid_set_idle()`:** Bypasses `hid_set_idle()` for VID:PID `0079:1846` during both device initialization (`usbhid_parse`) and post-reset recovery (`usbhid_post_reset`).
2. **Expands Report Descriptor to 4 Ports:** Intercepts the 198-byte descriptor and extends it dynamically to 396 bytes, duplicating the configuration for Report IDs 3 and 4 so Linux registers all 4 physical ports.
3. **Enables `HID_QUIRK_ALWAYS_POLL`:** Keeps interrupt polling active on endpoint `0x81` so events flow reliably to `evdev` and `SDL2`.

---

## 4. Quick Start: Build & Install

### Prerequisites
Install the kernel headers for your running kernel and standard compilation tools:

```bash
sudo apt update
sudo apt install -y build-essential linux-headers-$(uname -r) patch curl
```

### 1-Step Installation
Clone the repository, build the out-of-tree module, and install it:

```bash
git clone https://github.com/StudioSuiri/Mayflash-Linux-Kernel-Patch.git
cd Mayflash-Linux-Kernel-Patch

# Build the patched usbhid module against your running kernel headers
./scripts/build-module.sh

# Install with automatic backup of original module (requires sudo)
sudo ./scripts/install-module.sh
```

### Verification
Run the verification script to verify that your controller is detected:

```bash
./scripts/verify.sh
```

You should see 4 joysticks created in `/proc/bus/input/devices` and `/dev/input/`:
* Port 1: `/dev/input/js0` / `/dev/input/event18`
* Port 2: `/dev/input/js1` / `/dev/input/event19`
* Port 3: `/dev/input/js2` / `/dev/input/event20`
* Port 4: `/dev/input/js3` / `/dev/input/event21`

---

## 5. Rollback & Uninstallation

To restore your original distribution-supplied stock `usbhid` module:

```bash
sudo ./scripts/uninstall-module.sh
```

The script restores the `.orig` backup created during installation, re-runs `depmod -a`, and updates `initramfs`.

---

## 6. Mupen64Plus & Controller Mapping

For full setup instructions, see [`docs/mupen64plus.md`](docs/mupen64plus.md).

### Summary of Verified Mapping:
When using an N64 controller through the Mayflash adapter, the physical buttons translate as:

| N64 Button | Signal Detected | Recommended Config |
| :--- | :--- | :--- |
| **A** | `button(1)` | `A Button = button(1)` |
| **B** | `button(2)` | `B Button = button(2)` |
| **Z Trigger** | `button(7)` | `Z Trig = button(7)` |
| **Start** | `button(9)` | `Start = button(9)` |
| **L Trigger** | `button(4)` | `L Trig = button(4)` |
| **R Trigger** | `button(5)` | `R Trig = button(5)` |
| **D-Pad** | `hat(0)` | `DPad = hat(0 ...)` |
| **C-Buttons** | `axis(2)` & `axis(5)` | Horizontal: `axis(2)` / Vertical: `axis(5)` |
| **Analog Stick** | `axis(0)` & `axis(1)` | X Axis / Y Axis |

---

## 7. Kernel Compatibility & Limitations

* **Tested Version:** Linux `6.14.0-37-generic` (x86_64).
* **Compatibility:** The patch is designed for the modern Linux `usbhid` architecture (kernels 6.1+). Because replacing a distro kernel module is specific to the running kernel version, running a system kernel update (`apt upgrade`) that changes the kernel version will require running `./scripts/build-module.sh` and `sudo ./scripts/install-module.sh` for the new kernel version.
* **Reporting Other Hardware:** If your adapter has a different VID:PID or fails on another kernel release, please open an Issue on GitHub including the output of `./scripts/diagnose.sh`.

---

## 8. License & Attributions

* **Scripts and Documentation:** Released under the [MIT License](LICENSE).
* **Linux Kernel Patch:** Released under the terms of the [GNU General Public License v2 (GPL-2.0-only)](NOTICE), matching the upstream Linux kernel.
