# Mayflash 0079:1846 Linux HID Fix

> **A small, targeted Linux `usbhid` workaround that turns a stubborn `0079:1846` GameCube/N64 adapter into real Linux controller input.**

[![Linux](https://img.shields.io/badge/Linux-6.14%20tested-333?logo=linux)](https://kernel.org/)
[![USB](https://img.shields.io/badge/USB-0079%3A1846-333)](https://usb-ids.gowdy.us/read/UD/0079/1846)
[![Scripts](https://img.shields.io/badge/scripts-MIT-blue)](LICENSE)
[![Kernel patch](https://img.shields.io/badge/kernel%20patch-GPL--2.0-only-orange)](NOTICE)

---

## The short version

Some `0079:1846` adapters are visible to Linux at the USB level, but the generic HID driver fails during initialization:

```text
0079:1846 DragonRise Inc. GameCube Controller Adapter

usbhid 1-9:1.0: can't add hid device: -71
usbhid 1-9:1.0: probe with driver usbhid failed with error -71
```

When that happens, Linux sees the USB device but never turns it into usable controller input.

This repository contains a targeted patch for:

```text
drivers/hid/usbhid/hid-core.c
```

It is packaged as an **out-of-tree `usbhid.ko` build**, so users do **not** need to rebuild the entire Linux kernel.

The fix was developed and verified with a physical N64 controller, Mupen64Plus and a Linux `6.14.0-37-generic` system. The final result was real working N64 input, including the analog stick, C-buttons, triggers, Z, Start and D-pad.

---

## Why this exists

This started with a very ordinary retro-gaming problem:

> **"Linux can see my N64 adapter. Why can't I use the controller?"**

The adapter appeared in `lsusb`, but the kernel immediately rejected it with error `-71`. There was no controller in `/proc/bus/input/devices`, no useful `evdev` stream, and Mupen64Plus had nothing to bind to.

The obvious suspect was a missing controller driver. That turned out to be the wrong layer.

Linux already has Mayflash support through `hid_mf`, and upstream Linux has long known about the `0079:1846` family. The failure happened earlier: **generic `usbhid` could not successfully initialize this particular device/firmware behavior.**

The eventual workaround was deliberately narrow:

1. skip the broken HID `SET_IDLE` request for this exact VID:PID;
2. reconstruct the missing four-port report description;
3. force continuous HID polling;
4. build only the affected `usbhid` module instead of an entire kernel.

And it worked.

---

## Hardware: identify the USB device, not the plastic

The tested adapter reports:

| Property | Observed value |
|---|---|
| USB VID | `0079` |
| USB PID | `1846` |
| USB database name | DragonRise Inc. |
| Manufacturer string | `mayflash limited` |
| Product string | `GameCube Controller Adapter` |
| USB version | 2.00 |
| HID version | 1.10 |
| Interface | HID class (`03`) |
| Interrupt IN endpoint | `0x81` |
| IN packet size | 37 bytes |
| OUT endpoint | `0x02` |
| OUT packet size | 5 bytes |
| Report descriptor observed | 198 bytes before workaround |
| Successful test kernel | `6.14.0-37-generic` |

The physical enclosure is **not** the identification criterion.

The adapter used in development was sold as a generic N64 controller adapter and its physical shell is different from some commonly photographed Mayflash housings. Nevertheless, Linux identified it as `mayflash limited` / `0079:1846`, and the adapter worked after the fix.

There are inexpensive rebrands/clones and multiple physical designs in this ecosystem. The safest rule is therefore:

```text
Do not identify the device by its shell.
Identify it by VID:PID and USB descriptors.
```

The public USB ID database lists `0079:1846` as a GameCube controller adapter and associates it with the HongHao/DragonRise family:

- https://usb-ids.gowdy.us/read/UD/0079/1846

The marketplace listing used during the investigation was a generic N64 controller adapter listing:

- https://www.mercadolibre.com.co/adaptador-de-controlador-portatil-n64-adaptador-de-mando-n6/p/MCO2063486131

**Do not buy hardware solely because an enclosure looks similar. Check `lsusb` and look for `0079:1846`.**

---

## What failed before the patch

USB enumeration itself worked:

```text
Bus 001 Device 005: ID 0079:1846 DragonRise Inc. GameCube Controller Adapter
```

HID probing did not:

```text
usbhid 1-9:1.0: can't add hid device: -71
usbhid 1-9:1.0: probe with driver usbhid failed with error -71
```

The practical result was:

- no usable controller input;
- no Mayflash entry in `/proc/bus/input/devices`;
- no joystick device for the adapter;
- no usable `evdev` stream;
- Mupen64Plus could not see the physical controller.

Reloading the already-present `hid_mf` module did not solve the problem because the failure occurred before normal HID device handling could become useful.

---

## Root cause observed during the investigation

The failure was traced to the adapter's HID initialization behavior.

### 1. `SET_IDLE` breaks initialization

During normal `usbhid` parsing, Linux sends the standard HID `SET_IDLE` class request. This adapter firmware does not handle that request correctly.

The observed sequence was effectively:

```text
SET_IDLE
   ↓
adapter firmware rejects/stalls the request
   ↓
USB/HID transfer is left in an error state
   ↓
GET_REPORT_DESCRIPTOR fails
   ↓
-EPROTO / -71
   ↓
usbhid probe aborts
```

The workaround skips `hid_set_idle()` for `0079:1846` during both normal parsing and post-reset recovery.

### 2. The factory HID descriptor is incomplete for the four-port behavior

The device reports a 198-byte HID descriptor, while the observed adapter behavior contains four controller reports.

The workaround expands the descriptor to 396 bytes and duplicates the existing report definitions for the additional report IDs.

This allows Linux to represent the four physical controller ports independently.

### 3. Continuous polling is required

The patch also enables:

```c
HID_QUIRK_ALWAYS_POLL
```

for `0079:1846`, keeping the adapter's interrupt input path active.

---

## What the patch changes

The repository's kernel patch is intentionally small:

```text
1 file changed
29 insertions(+)
2 deletions(-)
```

It modifies only:

```text
drivers/hid/usbhid/hid-core.c
```

Specifically it:

1. skips `hid_set_idle()` for VID `0079`, PID `1846`;
2. expands a 198-byte report descriptor to 396 bytes when the expected descriptor is detected;
3. creates report IDs 3 and 4 for the additional ports;
4. enables `HID_QUIRK_ALWAYS_POLL` for the device;
5. applies the same `SET_IDLE` exception during post-reset recovery.

The exact patch is here:

[`patches/0001-mayflash-0079-1846-usbhid-fix.patch`](patches/0001-mayflash-0079-1846-usbhid-fix.patch)

---

## Why `hid_mf` alone was not enough

This distinction is important.

Linux already contains Mayflash support for this device family. In fact, upstream Linux previously added support for `0079:1846` and multi-input handling for the four controller ports.

The upstream history is documented here:

- https://lore-kernel.gnuweeb.org/lkml/20201223021813.2791612-16-sashal%40kernel.org/T/

The problem solved here occurs **earlier** in the stack:

```text
USB device
    │
    ▼
usbhid initialization       ← failure happened here
    │
    ▼
HID device registration
    │
    ▼
hid_mf / hid-generic
    │
    ▼
evdev / joystick / SDL2
    │
    ▼
emulator
```

So this project is not a replacement for Linux's existing Mayflash driver. It is a **device-specific compatibility workaround for the initialization failure**.

---

## Important: this is NOT a full kernel rebuild

Despite the repository name, users do not have to compile Linux from source.

The included tooling builds a replacement:

```text
usbhid.ko
```

against the currently running kernel headers.

Conceptually:

```text
Distribution kernel
       │
       ├── normal modules
       │
       └── patched usbhid.ko  ← this project
```

The scripts cover:

- preparing the build environment;
- obtaining the matching `usbhid` sources;
- applying the patch;
- compiling the module;
- backing up the distribution module;
- installing the patched module;
- running `depmod`;
- reloading `usbhid` when possible;
- updating initramfs;
- verification;
- rollback.

---

## Quick start

### Prerequisites

Debian/Ubuntu-family systems:

```bash
sudo apt update
sudo apt install -y build-essential linux-headers-$(uname -r) patch curl
```

### Clone

```bash
git clone https://github.com/StudioSuiri/Mayflash-Linux-Kernel-Patch.git
cd Mayflash-Linux-Kernel-Patch
```

### Build

```bash
./scripts/build-module.sh
```

### Install

```bash
sudo ./scripts/install-module.sh
```

### Verify

```bash
./scripts/verify.sh
```

For a read-only diagnostic report:

```bash
./scripts/diagnose.sh
```

---

## Repository tooling

| Tool | Purpose |
|---|---|
| `scripts/build-module.sh` | Build patched `usbhid.ko` for the running kernel |
| `scripts/install-module.sh` | Backup, install, reload and update initramfs |
| `scripts/uninstall-module.sh` | Roll back to the stock module |
| `scripts/verify.sh` | Check USB, kernel messages and live input events |
| `scripts/diagnose.sh` | Collect read-only system/device diagnostics |
| `patches/*.patch` | The actual kernel source change |
| `docs/mupen64plus.md` | N64/Mupen64Plus mapping |
| `docs/troubleshooting.md` | Failure modes and recovery |
| `tests/test_patch_format.sh` | Patch-format sanity test |

---

## What success looks like

At the USB layer:

```text
0079:1846 DragonRise Inc. GameCube Controller Adapter
```

At the kernel layer, the patched driver reports the workaround being applied, including descriptor expansion and `HID_QUIRK_ALWAYS_POLL`.

At the input layer, the adapter can expose independent controller devices for its physical ports.

**Do not hard-code `/dev/input/eventN` or `/dev/input/jsN`.** Those numbers depend on what other input devices are connected. Prefer `/dev/input/by-id/` or inspect `/proc/bus/input/devices`.

---

## The actual N64 setup

The real target was not a GameCube controller. It was a physical N64 controller connected through the adapter:

```text
Generic N64 controller
        │
        ▼
Adapter port
        │
        ▼
0079:1846 USB HID adapter
        │
        ▼
Linux usbhid
        │
        ▼
evdev / SDL2
        │
        ▼
Mupen64Plus
        │
        ▼
N64 game
```

The controller used during the successful test was a **generic translucent-green N64 controller** purchased as an inexpensive third-party unit.

Once the adapter successfully entered the Linux HID stack, the N64 controller itself required no special Linux kernel driver.

---

## Verified N64 mapping

The adapter presents N64 controls through a GameCube/generic HID-style layout:

| N64 control | Signal |
|---|---|
| Analog X | `axis(0)` |
| Analog Y | `axis(1)` |
| C-left | `axis(2-)` |
| C-right | `axis(2+)` |
| C-up | `axis(5-)` |
| C-down | `axis(5+)` |
| A | `button(1)` |
| B | `button(2)` |
| L | `button(4)` |
| R | `button(5)` |
| Z | `button(7)` |
| Start | `button(9)` |
| D-pad | `hat(0)` |

Full Mupen64Plus configuration is in [`docs/mupen64plus.md`](docs/mupen64plus.md).

### Super Mario 64 camera fix

During the first successful test, the controller worked but the camera felt wrong because the C-stick axes had initially been crossed.

The corrected mapping is:

```text
C-left   → axis(2-)
C-right  → axis(2+)
C-up     → axis(5-)
C-down   → axis(5+)
```

That restores the expected horizontal camera rotation and C-up/C-down camera behavior in *Super Mario 64*.

This is an **emulator configuration**, not part of the kernel patch.

---

## Tested environment

The known successful environment is:

```text
Kernel:       6.14.0-37-generic
Architecture: x86_64
USB host:     xHCI
USB device:   0079:1846
USB mode:     PC HID mode
Emulator:     Mupen64Plus
Controller:   generic translucent-green N64 controller
```

### Kernel updates

The patched module is tied to the kernel version/source it was built against. After a kernel update, rebuild it:

```bash
./scripts/build-module.sh
sudo ./scripts/install-module.sh
```

Do not copy a module built for one kernel release into another kernel's module tree.

Other kernel releases and distributions should be considered **untested until verified**.

---

## PC mode matters

This project targets:

```text
0079:1846
```

If your adapter exposes another VID:PID in another hardware mode, this patch does not automatically apply.

If your hardware has a mode switch, use the mode that exposes the normal PC HID identity before diagnosing Linux input problems.

---

## Troubleshooting

First run the read-only collector:

```bash
./scripts/diagnose.sh
```

Then check:

```bash
lsusb -d 0079:1846
```

and:

```bash
dmesg | grep -iE '0079:1846|usbhid|mayflash'
```

If you still see:

```text
can't add hid device: -71
```

check that:

1. the device really is `0079:1846`;
2. the patched module was built for `uname -r`;
3. the patched module was actually installed/loaded;
4. the adapter is in its PC HID mode.

More detailed failure modes are documented in [`docs/troubleshooting.md`](docs/troubleshooting.md).

---

## Rollback

To remove the patched module and restore the stock module:

```bash
sudo ./scripts/uninstall-module.sh
```

On Debian/Ubuntu systems, the distribution module can also be restored by reinstalling the kernel module package:

```bash
sudo apt install --reinstall linux-modules-$(uname -r)
```

---

## Repository layout

```text
Mayflash-Linux-Kernel-Patch/
├── README.md
├── LICENSE
├── NOTICE
│
├── patches/
│   └── 0001-mayflash-0079-1846-usbhid-fix.patch
│
├── scripts/
│   ├── build-module.sh
│   ├── diagnose.sh
│   ├── install-module.sh
│   ├── uninstall-module.sh
│   └── verify.sh
│
├── docs/
│   ├── mupen64plus.md
│   └── troubleshooting.md
│
└── tests/
    ├── README.md
    └── test_patch_format.sh
```

The patch is kept separate from the automation so it can be inspected, reviewed or eventually adapted into a cleaner upstream solution.

---

## Verification philosophy

There are three separate things to prove:

### 1. USB sees the device

```bash
lsusb -d 0079:1846
```

### 2. Linux created controller input devices

```bash
cat /proc/bus/input/devices
ls -l /dev/input/
```

### 3. Physical buttons actually generate events

Use `scripts/verify.sh`, `evtest`, SDL2 joystick tools or `python-evdev`.

Seeing the device in `lsusb` alone is **not success**. The goal of this project is the complete path from USB enumeration to real controller events.

---

## Upstream context

`0079:1846` is not an unknown device to Linux. Support for the Mayflash/DragonRise family has existed upstream for years, including multi-input handling for the four controller ports.

The upstream history is useful background:

- https://lore-kernel.gnuweeb.org/lkml/20201223021813.2791612-16-sashal%40kernel.org/T/

This project addresses a different failure mode: a particular device/firmware behavior that prevents the generic HID initialization sequence from completing on the tested modern xHCI/Linux stack.

---

## Known limitations and honest scope

- Tested target: `0079:1846`.
- This does **not** claim to support every N64-to-USB adapter.
- Similar-looking hardware can have different firmware and VID:PID values.
- The patch deliberately scopes behavior to one exact VID:PID.
- Kernel updates can require a rebuild/reinstall of the module.
- The build tooling currently assumes a Debian/Ubuntu-style kernel build tree.
- `/dev/input/eventN` and `/dev/input/jsN` numbers are dynamic.
- N64 button numbering may differ on other firmware revisions.
- The successful hardware identification is based on USB descriptors, not a claim that the physical enclosure is an official Mayflash product.

If your hardware differs, run:

```bash
./scripts/diagnose.sh
```

and include its output in an issue.

---

## Contributing

Useful contributions include:

- testing additional kernel releases;
- testing additional `0079:1846` hardware revisions;
- capturing HID descriptors from affected units;
- testing Intel, AMD and other xHCI hosts;
- improving the out-of-tree build/install flow;
- finding a cleaner upstreamable solution;
- documenting mappings for additional emulators.

When reporting a problem, include the VID:PID, kernel version, distribution, relevant `dmesg` output and `scripts/diagnose.sh` output.

---

## The story in one sentence

A cheap generic N64 adapter that Linux stubbornly recognized as `0079:1846` but refused to turn into a controller became a working N64 input device after a tiny, device-specific `usbhid` compatibility patch — and this repository exists so the next person does not have to spend an evening rediscovering why.

---

## Credits

This is an independent community project born from real hardware debugging and verification.

It is **not affiliated with Mayflash, DragonRise, Nintendo, Linux kernel maintainers or Mupen64Plus**.

If this saves you an evening of kernel archaeology, mission accomplished.

---

## License

- Repository scripts and documentation: **MIT License** — see [`LICENSE`](LICENSE).
- Kernel patch: **GPL-2.0-only**, matching the applicable Linux kernel terms — see [`NOTICE`](NOTICE).
