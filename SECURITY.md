# Security Policy

## Scope

This repository contains a small, device-specific Linux `usbhid` kernel workaround for USB VID:PID `0079:1846`.

It is **not** a kernel distribution, firmware package, binary driver download, or general-purpose USB utility.

The project intentionally publishes the source patch and build scripts rather than a precompiled kernel module. The goal is to make the change inspectable before installation.

## Before installing

Please read the patch before running any installation command:

```text
patches/0001-mayflash-0079-1846-usbhid-fix.patch
```

The installer replaces the `usbhid` module for the currently running kernel and may reload the HID subsystem. A mistake in a kernel module can make USB input devices temporarily unavailable or, in the worst case, affect system stability.

Recommended precautions:

- keep a working keyboard or another recovery path available;
- keep a backup of important work;
- know how to boot the previous kernel or remove the replacement module;
- build the module for the exact kernel you intend to use;
- do not broaden the VID:PID match without independent evidence;
- do not install a binary `usbhid.ko` obtained from an untrusted source.

## Trust model

The repository does not require a downloaded executable or a remote installer. The build process produces the module locally from Linux kernel source and the repository's visible patch.

The patch is deliberately limited to `0079:1846`. It should not be treated as a generic fix for unrelated HID devices.

## Reporting a security issue

If you discover that a script, patch, documentation instruction, or repository artifact introduces a security problem, please report it privately through GitHub's repository security reporting mechanism when available rather than immediately publishing exploit details in a public issue.

Include:

- the affected commit or version;
- distribution and kernel version;
- exact command or script involved;
- relevant logs;
- a minimal reproduction where practical.

Please do not include passwords, private keys, tokens, or other secrets in reports.

## What this project does not claim

A successful test on one adapter and one kernel does not prove that every device sold under the same marketplace name is identical. Hardware should be matched by observed USB descriptors, especially `0079:1846`, rather than by enclosure appearance alone.
