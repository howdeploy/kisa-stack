#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
revision=56c9e2b69e7d2b00f0f9481ae8c89f53810c1de5
mkdir -p "$root/.build"
checkout="$(mktemp -d "$root/.build/walker.XXXXXX")"
git clone https://github.com/abenz1267/walker.git "$checkout"
git -C "$checkout" checkout --detach "$revision"
git -C "$checkout" apply --check "$root/patches/walker/shoji.patch"
git -C "$checkout" apply "$root/patches/walker/shoji.patch"
(cd "$checkout" && cargo +1.94.0 build --release --locked)
mkdir -p "$HOME/.local/bin"
target="$HOME/.local/bin/walker-shoji"
if [[ -e "$target" || -L "$target" ]]; then
    backup="$(mktemp -d "$HOME/.local/bin/walker-shoji.backup.XXXXXX")"
    cp -a "$target" "$backup/"
    echo "Previous binary: $backup/walker-shoji"
fi
temporary="$(mktemp "$HOME/.local/bin/.walker-shoji.XXXXXX")"
install -m755 "$checkout/target/release/walker" "$temporary"
mv -f "$temporary" "$target"
echo "Installed $target; source retained in $checkout"
