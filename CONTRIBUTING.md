# Contributing

Thanks for helping test or improve this little compatibility project.

## What is most useful

The most valuable contributions are reproducible observations from real hardware:

- kernel versions and distributions;
- `lsusb -v -d 0079:1846` output;
- `dmesg` output from a failing and/or working kernel;
- HID report descriptors;
- xHCI host/platform differences;
- confirmation that the physical controls generate Linux input events;
- cleaner or more upstream-friendly fixes.

## Please keep the scope narrow

The current workaround targets **VID:PID `0079:1846`**. Do not expand the match to unrelated devices simply because they look similar or use the same marketplace description.

If a different adapter is affected, document its USB descriptors separately and open an issue before modifying the patch to cover it.

## Reproducing the original failure

The original hardware produced:

```text
0079:1846 DragonRise Inc. GameCube Controller Adapter
usbhid 1-9:1.0: can't add hid device: -71
usbhid 1-9:1.0: probe with driver usbhid failed with error -71
```

A useful report should distinguish three stages:

1. USB enumeration (`lsusb`);
2. HID/input registration (`/proc/bus/input/devices`, `/dev/input/`);
3. actual physical input events.

`lsusb` seeing a device is not sufficient evidence that the controller works.

## Code and documentation changes

Keep patches reviewable. Prefer small, targeted changes over generated or unrelated rewrites.

Do not commit:

- compiled kernel modules;
- firmware obtained from third parties;
- ROMs or other copyrighted game content;
- credentials, tokens, private keys, or local configuration;
- machine-specific absolute paths unless they are part of an intentional test fixture.

## Testing

Before submitting a change, run the repository's available tests and verification tools on a real device when possible. Report the exact kernel version used.

For kernel changes, explain why the change is limited to the affected device and what evidence supports it.
