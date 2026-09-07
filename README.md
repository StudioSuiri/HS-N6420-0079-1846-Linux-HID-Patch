# Mayflash 0079:1846 Linux HID Fix

> A community-documented Linux kernel workaround for the Mayflash/DragonRise **0079:1846 GameCube Controller Adapter** when the stock `usbhid` path fails with USB/HID error `-71`.

![Mayflash GameCube Controller Adapter](https://mayflash.com/upload/thumb_src/500_500/MAYFLASH_PRODUCT_W012_01.jpg)

*Official Mayflash product image of the W012 4-port adapter.*

[Mayflash W012 product page](https://www.mayflash.com/product/W012.html)

---

## Why does this repository exist?

This project started with a deceptively simple goal:

**Use a real Nintendo 64 controller on Linux.**

The hardware chain looked completely ordinary:

```text
N64 controller
      |
      v
Mayflash / DragonRise GameCube Controller Adapter
      |
      | USB
      v
Linux
      |
      v
Mupen64Plus
      |
      v
Nintendo 64 game
```

The adapter was detected by USB perfectly well:

```text
0079:1846 DragonRise Inc. GameCube Controller Adapter
Manufacturer: mayflash limited
Product: GameCube Controller Adapter
```

But Linux did not create an input device for it.

The important error was:

```text
usbhid 1-9:1.0: can't add hid device: -71
usbhid 1-9:1.0: probe with driver usbhid failed with error -71
```

So the problem was **not** that Linux could not see the USB device. Linux could see it. The failure happened while the HID device was being initialized.

---

## The rabbit hole

We initially explored several possible approaches: userspace virtual controllers, network transport, USB/IP, SDL mappings, emulator configuration and the existing Linux HID support for Mayflash devices.

That investigation produced an important discovery:

Linux 6.14 already contained the `hid_mf` driver and an alias for this exact device:

```text
alias hid:b0003g*v00000079p00001846 hid_mf
```

In other words, simply adding `0079:1846` to a driver was not the missing piece.

The failure was occurring earlier in the USB HID initialization path.

---

## What finally worked

The working solution was a small, device-specific modification to the Linux `usbhid` path.

The tested implementation does the following for `0079:1846`:

1. Avoids the problematic `hid_set_idle()` operation for this device.
2. Detects the adapter's factory HID report descriptor.
3. Expands the 198-byte descriptor into a 396-byte descriptor representing four controller report blocks.
4. Assigns report IDs `01`, `02`, `03` and `04` to the four controller ports.
5. Enables `HID_QUIRK_ALWAYS_POLL` for the adapter.
6. Rebuilds the affected `usbhid` kernel module.

The result is dramatically different: instead of a USB device that exists but has no usable Linux input node, the system exposes **four native controller devices**.

> The repository packages the reproducible patch and tooling. It does **not** contain a complete Linux kernel tree.

---

## Verified result

On the development machine, running kernel:

```text
6.14.0-37-generic
```

the patched adapter exposed four controller devices:

```text
Port 1 -> /dev/input/event18 + /dev/input/js0
Port 2 -> /dev/input/event19 + /dev/input/js1
Port 3 -> /dev/input/event20 + /dev/input/js2
Port 4 -> /dev/input/event21 + /dev/input/js3
```

SDL2 subsequently reported four joysticks, each with:

```text
axes   = 6
buttons = 16
hats   = 1
```

Mupen64Plus recognized the controllers as:

```text
mayflash limited GameCube Controller Adapter
```

The final validation was performed with an inexpensive **generic translucent-green N64-style controller** connected through the adapter.

And yes:

**Super Mario 64 actually worked.**

---

## Hardware

### Adapter

The affected hardware identifies itself as:

| Property | Value |
|---|---|
| USB VID | `0079` |
| USB PID | `1846` |
| USB name | `DragonRise Inc. GameCube Controller Adapter` |
| Manufacturer string | `mayflash limited` |
| Product string | `GameCube Controller Adapter` |
| Adapter model | Mayflash W012 family / 4-port GameCube adapter |

![Mayflash W012](https://mayflash.com/upload/thumb_src/500_500/MAYFLASH_PRODUCT_W012_02.jpg)

The official W012 documentation describes a four-port adapter with PC mode and USB connectivity. Mayflash also documents multiple firmware revisions for this hardware. See the official product documentation before changing firmware.

### Controller used for validation

The controller used during development was a generic, translucent-green N64-style controller purchased through Mercado Libre. It is **not** being presented as an official Nintendo controller or as a required model.

The important part of the reproduction is the USB adapter's identity:

```text
0079:1846
```

Different N64-style controllers may therefore work through the same adapter as long as their electrical/protocol compatibility with the adapter is normal.

---

## What this patch is — and is not

### This patch is

A Linux kernel/HID workaround for a specific USB HID adapter whose initialization fails with error `-71` on the tested system.

### This patch is not

- an N64 emulator
- an SDL controller mapper
- a Mupen64Plus plugin
- a replacement for the Mayflash firmware
- a generic GameCube controller driver
- a guarantee that every `0079:1846` revision will behave identically

The kernel patch solves the **Linux HID enumeration/input-device problem**.

Controller mappings for an emulator are a separate layer.

---

## Mupen64Plus mapping

Once Linux exposes the controller correctly, Mupen64Plus can consume the normal Linux/SDL input events.

The working configuration used during validation mapped the N64 C-buttons through the GameCube adapter's right-stick axes.

The relevant mapping was:

```text
DPad R   = hat(0 Right)
DPad L   = hat(0 Left)
DPad D   = hat(0 Down)
DPad U   = hat(0 Up)
Start    = button(9)
Z Trig   = button(6)
B Button = button(2)
A Button = button(1)
C Button R = axis(5+)
C Button L = axis(5-)
C Button D = axis(2+)
C Button U = axis(2-)
R Trig   = button(5)
L Trig   = button(4)
X Axis   = axis(0-,0+)
Y Axis   = axis(1-,1+)
```

### Important: C-button mapping is not the kernel patch

The C-button correction is an **emulator mapping correction**.

The kernel patch makes the controller visible and usable to Linux. Mupen64Plus then needs to interpret the resulting axes/buttons as N64 controls.

Keeping those layers separate is intentional.

---

## Installation

The exact installation procedure is intentionally kept version-aware because replacing a distro kernel module is inherently tied to the running kernel.

The repository's installation scripts will verify the running kernel and matching build environment before touching the system.

### Planned workflow

```text
1. Clone this repository
2. Run the diagnostic script
3. Verify that the adapter is 0079:1846
4. Install matching kernel headers/build tools
5. Apply the patch to the matching kernel source
6. Build the affected module
7. Back up the distro module
8. Install the patched module
9. Run depmod / initramfs update when required
10. Reconnect the adapter
11. Verify /dev/input and SDL
```

Do **not** install a module built for a different kernel version.

Do **not** blindly copy a prebuilt `usbhid.ko` from another machine.

The intended workflow is to build against the user's exact kernel.

---

## Verification

After installation, begin with:

```bash
uname -r
lsusb
```

The adapter should appear as:

```text
0079:1846 DragonRise Inc. GameCube Controller Adapter
```

Then inspect the kernel log:

```bash
dmesg | tail -80
```

The original failure:

```text
can't add hid device: -71
```

should no longer be the endpoint of the device initialization.

Then inspect Linux input devices:

```bash
ls -l /dev/input/by-id/
cat /proc/bus/input/devices
```

And, if `evdev` is installed:

```bash
python3 -c 'import evdev; print(evdev.list_devices())'
```

SDL2/Mupen64Plus can then be tested independently.

---

## Rollback

Kernel-module replacement should always be reversible.

The installation tooling keeps a backup of the original distro module before replacing it.

The repository will provide a dedicated rollback script rather than asking users to manually delete kernel files.

If something goes wrong, the safest recovery path is to restore the original module for the exact running kernel and regenerate module metadata/initramfs as appropriate for the distribution.

---

## Compatibility

The current implementation has been verified on:

```text
Linux kernel: 6.14.0-37-generic
Architecture: x86_64
USB device:   0079:1846
```

This does **not** mean the patch is guaranteed to apply unchanged to every Linux kernel.

Kernel HID internals change over time. The patch is therefore maintained as a version-specific kernel modification rather than pretending to be a universal binary driver.

If the patch fails on another kernel, please provide the output of the repository diagnostic script rather than modifying the patch blindly.

---

## Diagnostics

The repository includes a read-only diagnostic workflow intended to collect enough information to reproduce a report without exposing private data.

Useful information includes:

```text
uname -r
lsusb
relevant dmesg output
HID module information
module aliases
/dev/input devices
evdev capabilities
SDL joystick information
```

The diagnostic process should never modify the kernel or install anything.

---

## Why not just use USB/IP?

USB/IP was investigated during development because it looked like a way to move the physical USB device to another machine.

It turned out to be the wrong abstraction for this problem.

The adapter was physically connected to the Linux machine already. The useful goal was to make Linux understand the HID device correctly at the source.

Once the kernel-side problem was fixed, the normal Linux input stack worked and there was no reason to introduce a network transport layer.

---

## Why not just use a virtual controller?

A virtual controller can hide a broken physical input path, but it does not solve the underlying hardware support problem.

This project deliberately aims for:

```text
physical N64 controller
        ↓
physical USB adapter
        ↓
Linux HID
        ↓
Linux input subsystem
        ↓
SDL2
        ↓
emulator
```

That makes the adapter useful to normal Linux applications instead of tying the solution to one custom bridge program.

---

## Reproducibility philosophy

This repository is intended to document a real hardware debugging session and turn the successful fix into something another person can reproduce.

The important distinction is:

> **USB detection is not the same thing as HID usability.**

Linux could already see the adapter. The problem was getting the HID descriptor/device through the kernel's HID initialization path so that the normal input stack could take over.

That distinction is the central lesson of this project.

---

## Project status

**Working hardware proof:** yes.

**Physical N64 controller tested:** yes.

**Mupen64Plus tested:** yes.

**Four adapter ports exposed as Linux input devices:** yes.

**Kernel version tested:** `6.14.0-37-generic`.

**Universal upstream Linux support:** no claim is made here.

The remaining work is packaging the minimal kernel diff, build/install/rollback scripts, diagnostics and compatibility tests into a clean reproducible distribution.

---

## Credits and upstream material

The patch targets Linux kernel HID code. Linux kernel source remains under its original licensing and copyright terms; this repository does not relicense Linux kernel code.

The Mayflash W012 hardware and product imagery remain the property of Mayflash. Product images in this README are linked from Mayflash's official product site for identification/documentation purposes.

- [Mayflash W012 official product page](https://www.mayflash.com/product/W012.html)
- [Mayflash firmware/support pages](https://www.mayflash.com/Support/list-35.html)

---

## License

Original repository scripts and documentation will be released under a permissive open-source license.

Any Linux kernel code or derivative patch remains subject to the applicable Linux kernel licensing terms (GPL-2.0-only and associated notices).
