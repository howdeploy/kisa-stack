#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
qsb_bin="${QSB:-}"
if [[ -z "$qsb_bin" ]]; then
    qsb_bin="$(command -v qsb || command -v qsb6 || true)"
fi
if [[ -z "$qsb_bin" && -x /usr/lib/qt6/bin/qsb ]]; then qsb_bin=/usr/lib/qt6/bin/qsb; fi
if [[ -z "$qsb_bin" ]]; then echo 'Install Qt 6 Shader Tools or set QSB to its qsb executable.' >&2; exit 1; fi
for shader in "$root"/config/shoji-shell/shaders/*.frag; do
    "$qsb_bin" --glsl '100 es,120,150' --hlsl 50 --msl 12 -o "$shader.qsb" "$shader"
done
