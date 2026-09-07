# Mupen64Plus Configuration & Controller Mapping

This document details the configuration for Mupen64Plus when using a physical Nintendo 64 controller connected via the Mayflash adapter (`0079:1846`) in PC mode.

---

## 1. Physical Signal Translation

The Mayflash adapter translates physical N64 controller inputs into GameCube / generic PC HID signals:
- The **Main Analog Stick** maps to `axis(0)` (X) and `axis(1)` (Y).
- The **Yellow C-Buttons** are translated as GameCube **C-Stick coordinates**:
  - Horizontal movement: `axis(2)` (`ABS_Z`)
  - Vertical movement: `axis(5)` (`ABS_RZ`)
- The **Z Trigger** maps to `button(7)`.
- The **L and R Triggers** map to `button(4)` and `button(5)`.
- The **Start Button** maps to `button(9)`.
- The **A and B Buttons** map to `button(1)` and `button(2)`.
- The **D-Pad** maps to `hat(0)`.

---

## 2. Auto-Configuration (`InputAutoCfg.ini`)

Add the following block to `/usr/share/games/mupen64plus/InputAutoCfg.ini` (system-wide) or your local auto-configuration file:

```ini
[mayflash limited GameCube Controller Adapter]
plugged = True
plugin = 2
mouse = False
AnalogDeadzone = 4096,4096
AnalogPeak = 32768,32768
DPad R = hat(0 Right)
DPad L = hat(0 Left)
DPad D = hat(0 Down)
DPad U = hat(0 Up)
Start = button(9)
Z Trig = button(7)
B Button = button(2)
A Button = button(1)
C Button R = axis(2+)
C Button L = axis(2-)
C Button D = axis(5+)
C Button U = axis(5-)
R Trig = button(5)
L Trig = button(4)
Mempak switch =
Rumblepak switch =
X Axis = axis(0-,0+)
Y Axis = axis(1-,1+)
```

---

## 3. User Profile Configuration (`mupen64plus.cfg`)

In `~/.config/mupen64plus/mupen64plus.cfg`, under `[Input-SDL-Control1]`:

```ini
[Input-SDL-Control1]
version = 2.000000
mode = 2
device = 0
name = "mayflash limited GameCube Controller Adapter"
plugged = True
plugin = 2
mouse = False
AnalogDeadzone = "4096,4096"
AnalogPeak = "32768,32768"
DPad R = "hat(0 Right)"
DPad L = "hat(0 Left)"
DPad D = "hat(0 Down)"
DPad U = "hat(0 Up)"
Start = "button(9)"
Z Trig = "button(7)"
B Button = "button(2)"
A Button = "button(1)"
C Button R = "axis(2+)"
C Button L = "axis(2-)"
C Button D = "axis(5+)"
C Button U = "axis(5-)"
R Trig = "button(5)"
L Trig = "button(4)"
X Axis = "axis(0-,0+)"
Y Axis = "axis(1-,1+)"
```

---

## 4. Super Mario 64 Gameplay Notes

- **Z Trigger (`button(7)`):** Used for crouching, ground pound (in-air Z), long jumps (running Z + A), and crawling.
- **C-Buttons (Camera):**
  - **C-Up (`axis(5-)`):** First-person camera look.
  - **C-Down (`axis(5+)`):** Zoom in/out (Lakitu camera distance).
  - **C-Left (`axis(2-)`):** Rotate camera left.
  - **C-Right (`axis(2+)`):** Rotate camera right.
- **L Trigger:** Has no function in standard *Super Mario 64* gameplay.
- **D-Pad:** Unused in *Super Mario 64*, as movement is entirely analog.
