#!/usr/bin/env bash
set -u

pattern="${1:-keyboard|driver|hid|device|aula|akko|epomaker|keychron|sonix|redragon|royal|ajazz|attack|via|qmk}"

add_prefix() {
  local candidate="$1"
  [ -d "$candidate/drive_c" ] || return 0
  printf '%s\n' "$candidate"
}

find_prefixes() {
  local dir
  add_prefix "$HOME/.wine"

  for dir in \
    "$HOME"/PortProton/data/prefixes/* \
    "$HOME"/.local/share/bottles/bottles/* \
    "$HOME"/.var/app/com.usebottles.bottles/data/bottles/bottles/* \
    "$HOME"/.local/share/lutris/prefixes/* \
    "$HOME"/Games/*; do
    [ -e "$dir" ] || continue
    add_prefix "$dir"
  done
}

prefixes="$(find_prefixes | awk '!seen[$0]++')"

if [ -z "$prefixes" ]; then
  printf 'No Wine-style prefixes found in common locations.\n' >&2
else
  printf 'Wine-style prefixes:\n'
  printf '%s\n' "$prefixes" | sed 's/^/  /'
  printf '\n'
fi

printf 'Matching executables and shortcuts:\n'
matches=0

while IFS= read -r prefix; do
  [ -n "$prefix" ] || continue
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    if printf '%s\n' "$file" | grep -Eiq "$pattern"; then
      matches=1
      printf '  Prefix: %s\n' "$prefix"
      printf '  File:   %s\n\n' "$file"
    fi
  done < <(find "$prefix/drive_c" -maxdepth 8 -type f \( -iname '*.exe' -o -iname '*.lnk' \) 2>/dev/null)
done <<< "$prefixes"

for desktop_root in "$HOME/.local/share/applications" "$HOME/Desktop"; do
  [ -d "$desktop_root" ] || continue
  while IFS= read -r file; do
    if printf '%s\n' "$file" | grep -Eiq "$pattern" || grep -Eiq "$pattern" "$file" 2>/dev/null; then
      matches=1
      printf '  Desktop: %s\n\n' "$file"
    fi
  done < <(find "$desktop_root" -maxdepth 5 -type f -iname '*.desktop' 2>/dev/null)
done

if [ "$matches" -eq 0 ]; then
  printf '  No matching .exe, .lnk, or .desktop entries found for pattern: %s\n' "$pattern"
fi
