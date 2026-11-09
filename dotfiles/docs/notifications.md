# Notification policy and Quickshell

The desktop publishes the notification server changes as source and a pinned
build recipe. Stock Quickshell 0.3.1 does not expose the required
`NotificationServer.inhibited` and `allowedApplications` properties.

## Build and install the dependency

Install the core [dependency profile](../dependencies/arch.txt), including CMake,
Ninja, CLI11, Qt private development headers, Qt Shader Tools, SPIR-V tools and
jemalloc. The build uses the Quickshell revision and patch in `sources.json`.

```bash
./dotfiles/scripts/build-quickshell.sh
# Review and run the exact cmake --install command printed by the script.
```

The script only builds. Its printed install command targets
`${XDG_DATA_HOME:-$HOME/.local/share}/shoji-shell/quickshell`, leaving the system
package alone. The shell launcher uses that private executable. If you maintain
another compatible patched build, set `SHOJI_QUICKSHELL` to its absolute executable
path in the local `integrations.env` and while running the config installer.
Quickshell uses private Qt APIs, so rebuild it after a Qt upgrade.

Install/update the desktop through the existing [installer](install.md) after the
private binary is present. Preflight fails before moving config if it is absent.
No build recipe starts another panel or restarts the current session.

## Behaviour

Settings → Notifications controls reception and explicit application exceptions.
When disabled, new unapproved messages do not create cards or tracked history.
Critical urgency does not grant an implicit exception. Allowed applications are
resolved through the installing user's desktop entries; no app list is preset.

The native server reports caller-specific `org.freedesktop.Notifications.Inhibited`
and targets policy changes to each known caller. Clients that respect that protocol
can suppress their own notification sounds while explicit exceptions remain active.
Arbitrary in-app sounds and overlays are outside this protocol. No global audio
mute is introduced. The WM additionally hides known standalone Steam toast windows
unless allowed by the same policy.

The local `notification-policy.json` is created only on use, ignored by Git and
preserved during config upgrades. An invalid/unreadable policy fails closed and
shows an error without replacing the file. Policy changes apply immediately;
save failure is reported separately. Restoring an older stock Quickshell also
requires restoring its matching older QML through the installer backup manifest.

## Validation boundary

The patch applies to pinned upstream source. The earlier installed local variant
was built and loaded, but this source publication has no new native build or GUI/
sound acceptance. Caller sound behaviour still depends on the application.
