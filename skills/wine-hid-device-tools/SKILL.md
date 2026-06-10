---
name: wine-hid-device-tools
description: Configure, troubleshoot, or relaunch Windows vendor utilities for USB HID keyboards and similar devices under Wine, PortProton, Bottles, Lutris, or Proton when the app cannot detect the device, reports sleep mode, needs hidraw/udev permissions, or requires winebus registry tuning.
metadata:
  hermes:
    tags: [wine, hid, usb, keyboard, udev, linux]
---

# Wine HID Device Tools

> **Hermes:** все команды и скрипты этого скилла — обычный bash, запускай через `terminal`. Вывод команд показывай пользователю как есть.

## Goal

Help users run Windows keyboard and HID vendor tools on Linux when the device works as normal input but the configuration app cannot detect or control it. Diagnose Linux USB/HID visibility, `hidraw` permissions, the correct Wine prefix, and `winebus` settings before recommending a Windows VM.

Do not run Wine as root. Do not assume `~/.wine` is the correct prefix.

## Quick Workflow

1. Confirm the device is wired over USB data, not only charging or still using Bluetooth/2.4 GHz.
2. Find the device's VID/PID and `hidraw` nodes.
3. Verify user access to the relevant `/dev/hidraw*` nodes.
4. Generate and apply a udev rule if permissions are missing.
5. Find the prefix that contains the installed vendor app.
6. Apply `winebus` settings to that exact prefix.
7. Relaunch the installed `.exe` with careful shell quoting.

Use scripts first when available; they are read-only except for printing commands.

## Discovery Scripts

List HID raw devices:

```bash
scripts/discover_hid_devices.sh
scripts/discover_hid_devices.sh 'aula|sonix|keyboard|0c45'
```

Find likely Wine prefixes and installed vendor executables:

```bash
scripts/find_wine_prefix_apps.sh
scripts/find_wine_prefix_apps.sh 'aula|akko|keychron|keyboard|driver'
```

Print setup commands for a known VID/PID:

```bash
scripts/print_hid_setup_commands.sh 0c45:800a
scripts/print_hid_setup_commands.sh 0c45:800a "/path/to/prefix"
```

The third script prints commands only. Review them with the user before applying `sudo` or registry changes.

## Manual HID Checks

Use these when scripts are unavailable or more detail is needed:

```bash
lsusb
sudo dmesg -wH | grep -Ei --line-buffered 'usb|hid|hidraw|keyboard|device'
```

Inspect `hidraw` metadata:

```bash
for d in /sys/class/hidraw/hidraw*; do
  [ -r "$d/device/uevent" ] || continue
  echo "/dev/${d##*/}"
  cat "$d/device/uevent"
  echo
done
```

Relevant metadata often looks like:

```text
HID_ID=0003:00000C45:0000800A
HID_NAME=SONiX AULA F75Max
MODALIAS=hid:b0003g0001v00000C45p0000800A
```

Here the VID/PID is `0c45:800a`.

Check permissions:

```bash
ls -l /dev/hidraw*
```

The relevant nodes must be writable by the user, for example `crw-rw-rw-` or via ACL (`+`). If not, create a udev rule using the real VID/PID:

```bash
sudo tee /etc/udev/rules.d/70-hid-VID-PID.rules >/dev/null <<'EOF'
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="VID", ATTRS{idProduct}=="PID", TAG+="uaccess", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="VID", ATTR{idProduct}=="PID", TAG+="uaccess", MODE="0666"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger
```

Replace `VID` and `PID`, then physically unplug and reconnect the device.

## Wine Prefix Setup

Apply registry settings only to the prefix that contains the vendor app. Common prefix roots include:

```text
~/.wine
~/PortProton/data/prefixes/*
~/.local/share/bottles/bottles/*
~/.var/app/com.usebottles.bottles/data/bottles/bottles/*
~/.local/share/lutris/prefixes/*
```

For a known prefix and VID/PID:

```bash
WINEPREFIX="/path/to/prefix" wineserver -k

WINEPREFIX="/path/to/prefix" wine reg add 'HKLM\System\CurrentControlSet\Services\winebus' /v DisableHidraw /t REG_DWORD /d 0 /f
WINEPREFIX="/path/to/prefix" wine reg add 'HKLM\System\CurrentControlSet\Services\winebus' /v EnableHidraw /t REG_SZ /d "VID:PID" /f
WINEPREFIX="/path/to/prefix" wine reg add 'HKLM\System\CurrentControlSet\Services\winebus' /v 'Enable SDL' /t REG_DWORD /d 0 /f
WINEPREFIX="/path/to/prefix" wine reg add 'HKLM\System\CurrentControlSet\Services\winebus' /v DisableInput /t REG_DWORD /d 1 /f

WINEPREFIX="/path/to/prefix" wineserver -k
```

Verify if needed:

```bash
rg -n 'DisableHidraw|EnableHidraw|Enable SDL|DisableInput' "/path/to/prefix/system.reg"
```

Expected values:

```text
"DisableHidraw"=dword:00000000
"DisableInput"=dword:00000001
"Enable SDL"=dword:00000000
"EnableHidraw"="VID:PID"
```

## Relaunching the App

Prefer changing into the app directory before launching to avoid broken shell wrapping:

```bash
cd "/path/to/prefix/drive_c/Program Files (x86)/Vendor App"
WINEPREFIX="/path/to/prefix" wine App.exe
```

For background launch:

```bash
setsid -f env WINEPREFIX="/path/to/prefix" wine "/path/to/prefix/drive_c/Program Files (x86)/Vendor App/App.exe"
```

If a quoted path is split across lines inside the filename, Wine may try to open a path containing `\n` and fail. Keep the quoted path on one line or use `cd`.

## Interpreting Common Output

- `libEGL warning`: usually graphics noise, not the HID issue.
- `fixme:wineusb:query_id Unhandled ID query type 0x5`: common Wine noise.
- `err:hid:udev_bus_init UDEV monitor creation failed`: Wine may not monitor udev events; still check direct `hidraw` access and prefix settings.
- App says `sleep mode`: the app may see the USB identity but fail to open the control HID interface. Recheck `hidraw` permissions and `winebus` in the correct prefix.
- `wineserver -k` exits with `1`: often means there was no active server; continue unless another error appears.

## Fallback

If Linux sees the device, `hidraw` permissions are correct, the correct prefix has `winebus` configured, and the app still cannot control the device, explain that the proprietary HID protocol or driver behavior may not work under Wine. Recommend Windows VM USB passthrough or a real Windows machine for configuration, then return to Linux after settings are stored on the device.
