# Software and dependency profiles

The reference platform is Manjaro/Arch, snapshot **2026-10-28 (Europe/Moscow)**.
The files below serve different purposes:

| File | Purpose |
| --- | --- |
| `arch.txt` | Core desktop, build tools and panel commands; install before building the desktop |
| `arch-wallpaper.txt` | Additional dependencies for the private wallpaper-engine/mpv build |
| `arch-integrations.txt` | Optional Node.js and GitHub CLI adapters; no logins or accounts |
| `reference-repository-packages.txt` | Explicitly installed packages recognized by the reference machine's pacman sync databases, with versions (`pacman -Qen`) |
| `reference-foreign-packages.txt` | Explicitly installed foreign/local packages with versions (`pacman -Qem`); these are not all guaranteed to be AUR packages |
| `reference-flatpak-apps.txt` | Installed Flatpak application IDs, branches and remotes; empty at this snapshot |

The reference inventories are informational. Do not feed them blindly to pacman
or an AUR helper: they include a separate KDE recovery desktop, kernels, firmware,
GPU drivers, unrelated applications and locally built packages. Versions record
what was installed; they do not guarantee those binaries remain in a rolling
repository. The curated profiles and pinned source builds are the desktop setup.

Install the core and, if wanted, wallpaper dependencies using the commands in
[installation](../docs/install.md). On another distribution translate package
names and install equivalent recent libraries. Do not copy NVIDIA/kernel packages
from the reference inventory onto different hardware.

## Applications and external inputs

| Component | How it is supplied |
| --- | --- |
| ShojiWM | Exact public fork revision in `sources.json`, built by `build-shojiwm.sh` |
| Quickshell, Ghostty, Dolphin, audio/network/Bluetooth controls | `arch.txt` |
| Walker | Exact source plus theme patch, built by `build-walker.sh` |
| Elephant | Install `elephant-bin`, `elephant-desktopapplications-bin`, `elephant-files-bin`, `elephant-providerlist-bin`; the reference versions are recorded |
| Animated wallpaper renderer | Private pinned engine, CEF runtime and mpv, built by `build-wallpaper-engine.sh`; no system engine package is required for this path |
| Steam and Wallpaper Engine content | Install Steam for your distribution and supply your own Wallpaper Engine assets and Workshop subscriptions |
| MateEngine | Pinned Mate Engine Plus source includes the lock/voice bridge; see [MateEngine setup](../docs/mateengine.md). Unity and owned Steam inputs are separate |
| Brave, Steam, Happ, Codex Desktop | Optional applications; not required by the shell. Reference pacman entries cover some of them; Codex Desktop and manual app installations are not represented by pacman |
| GitHub, Vast, limits, sessions, Hermes, weather | Optional [integrations](../docs/widgets.md); install the chosen CLI/runtime and authenticate locally |

The default dock pins only Ghostty and Dolphin. Pins whose desktop entry is
absent are hidden; edit `Dock.qml` to add your own installed desktop-entry IDs.
The first launch uses the empty widget preset and bundled neutral background.
Select a preset with Super+W, then explicitly enable the integrations you want.

No credential store, model, wallpaper collection, paid asset, manually installed
application binary or personal account setting is part of these inventories.
