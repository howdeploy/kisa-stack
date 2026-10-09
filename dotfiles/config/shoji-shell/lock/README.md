# Shoji session lock

An independent Quickshell process using `WlSessionLock` and system PAM password
authentication. The panel starts it through `LockScreen.qml`; ShojiWM's
`lock-session` binding runs the same launcher on `Super+L`.

```bash
# Validate without locking or attempting authentication:
python3 ~/.config/shoji-shell/lock/launch.py --check
# Open a regular window; no lock and no password checking:
python3 ~/.config/shoji-shell/lock/launch.py --preview
# Lock (also available through Super+L or the profile's lock button):
python3 ~/.config/shoji-shell/lock/launch.py
```

The locker covers every output through `WlSessionLockSurface`, including newly
connected outputs. A successful PAM result after a hidden password challenge is
the only unlock path. IPC exposes only `session status`; no password or unlock
method exists. Passwords are not passed as arguments, written to disk or logged.
Typing is cleared after submission and after failed authentication. A 1.5-second
UI delay complements the distribution's PAM failure policy.

All output views bind to a shared password buffer in `SessionLock.qml`. Editing,
deleting and clearing from any monitor updates the masked text on every other
monitor without moving focus or changing the active field's cursor/selection.
Newly connected output views initialise from that same buffer.

The process detaches from the panel and disables Quickshell's file watcher. Source
edits apply to the next lock; panel reloads do not destroy an active lock. The
launcher waits for the compositor's `secure` acknowledgement before reporting
success. Runtime diagnostics are in `$XDG_RUNTIME_DIR/shoji-lock/locker.log`.

## PAM and portability

The launcher prefers `/etc/pam.d/shoji-lock`, then `omarchy-lock-password`,
`swaylock`, or `hyprlock`. On Arch/Manjaro/Omarchy, the bundled `pam/shoji-lock`
fallback includes the installed `system-auth` and `system-local-login` policies.
Its private runtime directory links the distro's PAM files so transitive includes
resolve correctly. No root-owned file is changed.

For another distribution, provide a distro-appropriate password-only
`/etc/pam.d/shoji-lock`. Multi-step PAM challenges, password expiry changes and
fingerprints are not supported by this initial version. The screen stays locked
if PAM fails. The fallback has only been source-checked until tested on that distro.

## Initial manual verification

Save your work, run `--check`, and open the preview first. Then lock manually and
verify: wrong password keeps the lock; correct password restores the same session;
EN/RU switching works; all monitors stay covered; connecting/disconnecting an
output keeps the lock; reloading the panel leaves the locker running.
Automatic idle/sleep locking is not enabled by this change.

If the locker crashes, a conformant compositor keeps the session locked. Switch
to another TTY with Ctrl+Alt+F3 and log in. Save work where possible before ending
the affected graphical session using `loginctl terminate-session SESSION_ID`.
Restarting Quickshell is not assumed to recover an orphaned lock.

## Move into your fork

Copy `lock/`, `lock.qml`, `lock-preview.qml`, `lock-check.qml`, `lock-input-test.qml`, `LockScreen.qml`,
`icons/home-lock.svg` and the changes in `qmldir`,
`shell.qml`, `HomeSystemCard.qml` and `shojiwm/src/index.tsx` into the corresponding
`dotfiles/config/` paths. Keep `Theme.qml`, `UiText.qml`, `ActionButton.qml` and
`assets/default-wallpaper.svg` with the shell. No username, credential, private
wallpaper or absolute home path is embedded in the implementation.

## Design reference lock

The existing Shoji theme owns canvas, typography, accent, radii and button roles.
The installed Omarchy lock contributes only the password-first flow and opaque
fallback background. The Refero craft guide contributes labelled input, keyboard
focus and inline failure states; live Refero research was unavailable due to an
inactive subscription. Preserve the clock above the form, the single password
field, and the existing theme tokens. A static local wallpaper is selected at
launch, darkened for readability; no generated media or live effects are needed.

Visual checks should cover 1280×800, 640×480 and 360×640, including error states.

Launcher regression checks (do not lock or authenticate):

```bash
python3 ~/.config/shoji-shell/lock/test_launch.py
quickshell --path ~/.config/shoji-shell/lock-input-test.qml
/usr/lib/qt6/bin/qmllint -I ~/.config/shoji-shell ~/.config/shoji-shell/lock/*.qml
```
