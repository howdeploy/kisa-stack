# Optional MateEngine screensaver behind the lock

The compositor and QML locker work without MateEngine. To reproduce the
screensaver integration, the MateEngine app bridge must understand the
compositor's actual `sessionLocked` state; copying desktop QML cannot add this
capability to an older player.

`sources.json` pins [Mate Engine Plus](https://github.com/howdeploy/Mate-Engine-Plus)
at `34136f2595925eb7dbf6ea9c5f7eb7c7ddc8c5a7`. That public revision includes
the lock-state bridge, voice client/IPC, corrected seating and edge hiding,
dance bundle/queue fixes, menu positioning and optional wardrobe dependencies.

Prepare a separate source checkout:

```bash
git clone https://github.com/howdeploy/Mate-Engine-Plus.git mateengine-lock
git -C mateengine-lock checkout --detach 34136f2595925eb7dbf6ea9c5f7eb7c7ddc8c5a7
```

Follow the pinned project's
[Linux build guide](https://github.com/howdeploy/Mate-Engine-Plus/blob/34136f2595925eb7dbf6ea9c5f7eb7c7ddc8c5a7/docs/BUILD.md).
Build the application and finalize its matching bridge together; copying one
DLL from a different player is not a supported setup. The earlier
`patches/mateengine/session-lock.patch` is retained only as a source export
against `211ba1d`; **do not apply it again** to the current pinned revision.

Unity 6000.2.6f2, the build guide's managed/native dependencies and your owned
Steam X3.4 player/export are required. Models, DLC, Workshop data, app settings
and Steam authentication are not supplied. A generic Wine/Windows player does
not implement this Linux bridge.

Build/install the pinned ShojiWM fork and desktop files separately. When ready,
launch your own Linux MateEngine build using its wrapper, enable its Big Screen
screensaver, and perform a deliberate lock/unlock check. The config selects only
the current MateEngine root and wallpaper roots as lock backgrounds. PAM owns
authentication; background clients never receive lock input.

The optional voice client uses a private local Unix socket and standard-library
Python; it does not install a voice assistant, listen on TCP or authenticate any
remote service. See the pinned project's voice guide for commands and limits.
Wardrobe dependencies need explicit model-specific rules; no outfits are supplied.

The user accepted the earlier local wallpaper/screensaver behavior after the
deadlock correction. The generic public compositor API and this clean-source
build combination have not been built or tested together during publication.
Publishing source does not replace the private app build or local profile.
