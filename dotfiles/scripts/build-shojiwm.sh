#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
revision="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["shojiwm"]["revision"])' "$root/sources.json")"
mkdir -p "$root/.build"
checkout="$(mktemp -d "$root/.build/shojiwm.XXXXXX")"
git clone --branch main https://github.com/howdeploy/ShojiWM.git "$checkout"
git -C "$checkout" checkout --detach "$revision"
echo 'Building the pinned fork. Native libraries and Rust 1.94.0 must already be installed.'
(cd "$checkout" && cargo +1.94.0 build --locked --release -p shoji_wm -p xdg-desktop-portal-shojiwm)
echo "Build ready in $checkout"
echo "Review upstream dist/install.sh, then install the system components:"
printf 'cd %q && ./dist/install.sh --no-build --no-config\n' "$checkout"
