#!/usr/bin/env bash
set -u

filter="${1:-}"
found=0

for node in /sys/class/hidraw/hidraw*; do
  [ -e "$node" ] || continue
  uevent="$node/device/uevent"
  [ -r "$uevent" ] || continue

  dev="/dev/${node##*/}"
  info="$(cat "$uevent")"

  if [ -n "$filter" ] && ! printf '%s\n' "$dev" "$info" | grep -Eiq "$filter"; then
    continue
  fi

  name="$(printf '%s\n' "$info" | sed -n 's/^HID_NAME=//p')"
  hid_id="$(printf '%s\n' "$info" | sed -n 's/^HID_ID=//p')"
  modalias="$(printf '%s\n' "$info" | sed -n 's/^MODALIAS=//p')"
  vid_pid=""

  if [[ "$modalias" =~ v0*([[:xdigit:]]{4})p0*([[:xdigit:]]{4}) ]]; then
    vid_pid="${BASH_REMATCH[1],,}:${BASH_REMATCH[2],,}"
  elif [[ "$hid_id" =~ :0*([[:xdigit:]]{4}):0*([[:xdigit:]]{4})$ ]]; then
    vid_pid="${BASH_REMATCH[1],,}:${BASH_REMATCH[2],,}"
  fi

  found=1
  printf '%s\n' "Device: $dev"
  [ -n "$name" ] && printf '  Name: %s\n' "$name"
  [ -n "$vid_pid" ] && printf '  VID:PID: %s\n' "$vid_pid"
  [ -n "$hid_id" ] && printf '  HID_ID: %s\n' "$hid_id"
  [ -n "$modalias" ] && printf '  MODALIAS: %s\n' "$modalias"
  [ -e "$dev" ] && printf '  Permissions: %s\n' "$(ls -l "$dev")"
  printf '\n'
done

if [ "$found" -eq 0 ]; then
  if [ -n "$filter" ]; then
    printf 'No hidraw devices matched filter: %s\n' "$filter" >&2
  else
    printf 'No hidraw devices found.\n' >&2
  fi
  exit 1
fi
