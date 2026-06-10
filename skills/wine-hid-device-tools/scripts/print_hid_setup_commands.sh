#!/usr/bin/env bash
set -u

usage() {
  printf 'Usage: %s VID:PID [WINEPREFIX]\n' "${0##*/}" >&2
  printf 'Example: %s 0c45:800a "/path/to/prefix"\n' "${0##*/}" >&2
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  usage
  exit 2
fi

vid_pid="${1,,}"
wineprefix="${2:-}"

if [[ ! "$vid_pid" =~ ^([[:xdigit:]]{4}):([[:xdigit:]]{4})$ ]]; then
  printf 'Invalid VID:PID: %s\n' "$vid_pid" >&2
  usage
  exit 2
fi

vid="${BASH_REMATCH[1]}"
pid="${BASH_REMATCH[2]}"
rule="/etc/udev/rules.d/70-hid-${vid}-${pid}.rules"

if [ -n "$wineprefix" ]; then
  prefix_assign="WINEPREFIX=$(printf '%q' "$wineprefix") "
else
  prefix_assign=""
fi

cat <<EOF
# Review, then run these commands if they match the target device.

sudo tee "$rule" >/dev/null <<'RULE'
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="$vid", ATTRS{idProduct}=="$pid", TAG+="uaccess", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="$vid", ATTR{idProduct}=="$pid", TAG+="uaccess", MODE="0666"
RULE

sudo udevadm control --reload-rules
sudo udevadm trigger

# Physically unplug and reconnect the USB device after reloading udev.

${prefix_assign}wineserver -k
${prefix_assign}wine reg add 'HKLM\System\CurrentControlSet\Services\winebus' /v DisableHidraw /t REG_DWORD /d 0 /f
${prefix_assign}wine reg add 'HKLM\System\CurrentControlSet\Services\winebus' /v EnableHidraw /t REG_SZ /d "$vid:$pid" /f
${prefix_assign}wine reg add 'HKLM\System\CurrentControlSet\Services\winebus' /v 'Enable SDL' /t REG_DWORD /d 0 /f
${prefix_assign}wine reg add 'HKLM\System\CurrentControlSet\Services\winebus' /v DisableInput /t REG_DWORD /d 1 /f
${prefix_assign}wineserver -k
EOF
