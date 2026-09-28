# Fork and contribution provenance

The compositor is [howdeploy/ShojiWM](https://github.com/howdeploy/ShojiWM), an
integration of upstream ShojiWM and five contributions by howdeploy. These
dotfiles are a separate user configuration layer; the fork itself ships the
upstream default config, not this desktop.

- Integration branch: [`howdeploy/stack`](https://github.com/howdeploy/ShojiWM/tree/howdeploy/stack).
- Pinned revision: [`f61a5f98117c355fe131e3d550970de0ed6a5120`](https://github.com/howdeploy/ShojiWM/commit/f61a5f98117c355fe131e3d550970de0ed6a5120).
- Upstream baseline: `3fef0c862caab18332947f5e4ede83ff446312a7`.
- Fork [`FORK.md`](https://github.com/howdeploy/ShojiWM/blob/f61a5f98117c355fe131e3d550970de0ed6a5120/FORK.md)
  explains branch structure and validation limits.

| Upstream PR | What the desktop uses |
| --- | --- |
| [#105: keyboard layout status](https://github.com/bea4dev/ShojiWM/pull/105) | External keyboard-layout indicator and layout-change OSD |
| [#106: keyboard LEDs](https://github.com/bea4dev/ShojiWM/pull/106) | Hardware lock-state synchronization, including newly attached keyboards |
| [#107: cursor scaling](https://github.com/bea4dev/ShojiWM/pull/107) | Native Wayland cursor scaling and viewport handling |
| [#108: full-window subsurfaces](https://github.com/bea4dev/ShojiWM/pull/108) | Full-source replacement effects include child surfaces |
| [#109: native workspace waves](https://github.com/bea4dev/ShojiWM/pull/109) | Optional native TTY workspace wave transition API |

All five PRs were open when checked on 2026-09-28. Their present status may differ;
the pinned integration revision, not the status badge or a moving branch head,
defines this snapshot. Fork `main` remains the upstream baseline at this snapshot.

The original desktop ran a locally built compositor containing these changes.
The extracted public integration branch has not been rebuilt and run as part of
the dotfiles packaging checks. Do not describe this bundle as a verified binary
release or claim full cross-distribution/GPU coverage.
