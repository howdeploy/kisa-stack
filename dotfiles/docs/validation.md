# Validation record

## 2026-10-28 delayed-frame media reply follow-up

The media patch is refreshed to PR #711 revision `2de3518`. Available D-Bus
replies are read and dispatched before the application deadline is applied;
a completed reply is retained even when a frame delay outlasts 250 ms.
Each new request also gets an immediate zero-timeout I/O attempt.

Two regression sections use a private-bus peer returning a real Position reply:
one covers an already completed reply and the other a reply still unread in the
socket when the application deadline has expired. They force only the application
deadline, without sleeping to simulate the frame delay. The existing incomplete
request expiry check remains. These tests and a new build were not run.
The regenerated media/crop patches passed `git apply --check` against the
pinned engine source in a temporary directory.
No installed runtime or live session was changed.

## 2026-10-28 publication completeness follow-up

The source publication now pins ShojiWM `d78b72a` directly, includes installed
repository/foreign/Flatpak application inventories, removes unavailable dock
pins, and supplies a complete private wallpaper engine/CEF/mpv build path.
The installer checks desktop prerequisites and validates a wallpaper bundle
before backing up an existing runtime. The helper bypasses system launcher
wrappers when using that private runtime.

The media patch now includes PR #711's asynchronous revision `afeb74d`;
the earlier synchronous ASan/build results do not validate it. The optional
MateEngine pin is now public `34136f2`, including the accumulated Linux/voice
updates. Its earlier lock-only patch export against `211ba1d` is archival.
Source pins, launch/install paths and publication
scope were reviewed. Tests were added for launch selection and bundle
replacement/rejection, but were not run. No build, lint, typecheck, installation,
session reload, player launch or graphical check was performed for this update.
The staged privacy scan covered 378 publication files with zero findings.
Engine/media, mpv and MateEngine patches passed `git apply --check` against
their pinned source snapshots in temporary directories. These are source and
publication checks, not a runtime test.

## 2026-10-28 generic lock API publication

The compatibility fork main now contains commit
[`d78b72a`](https://github.com/howdeploy/ShojiWM/commit/d78b72a4971068e37b31ea67dd2eff760fb04281).
The generic port to upstream main `44e8ce9` is
[draft PR #163](https://github.com/bea4dev/ShojiWM/pull/163), head `27fe62a`.
The local patch export includes the same compatibility-fork changes against the
existing `031f051` pin. The public TS adapter supports the new exact-runtime-ID
API and the earlier installed implementation.

This publication involved source/diff and remote-ref review, not builds, tests,
typechecking or runtime validation. A focused native ID-validation/owner-lifecycle
check is included but has not been run. The installed compositor and live WM
adapter were retained; the user's successful background/screensaver checks
apply to the earlier corrected local implementation.

Current upstream source already handles layer ordering, per-layer damage,
frame callbacks/presentation feedback, and explicit-sync/NVIDIA buffer holds.
No additional compositor video-wallpaper fix was identified by source review.
The earlier media-memory patches remain changes to linux-wallpaperengine/mpv.

## 2026-10-28 first lock attempt: compositor deadlock

The user reported a freeze immediately after Super+L. The compositor log ended
at 07:44:34 Europe/Moscow, while system services continued until 07:49. The kernel
journal contained no corresponding GPU fault or OOM kill. Source review found
a self-deadlock in the newly added lock wallpaper renderer: it retained the
output LayerMap guard across a helper that locks the same map. The shared
TTY/winit path now collects owned layer handles before rendering and releases
the mutex first. No hung-process stack was available. Runtime validation of the
correction is pending; no lock/authentication/DPMS test was run by the agent.
The corrected locked/offline release build passed in 3m07s and was installed
locally. The installed binary matched its build artifact by SHA256. No session
or process was restarted. The public compositor patch contains the same fix.

## 2026-10-28 lock-scene build and local installation

With explicit permission, the native compositor patch built successfully using
Rust 1.94.0, `--locked --offline --release`, with one build job. The managed-only
MateEngine application and bridge compiled; the existing patcher retained all
47 bridge call sites. Bun bundled 19 config modules, and Qt's bytecode compiler
compiled `Lock.qml`, `LockFace.qml` and `LockScene.qml`.

The new compositor, changed SDK file, managed DLLs and live QML/TS configuration
were installed with backups. Installed files matched their build artifacts.
The current compositor process was not restarted; no MateEngine player was
started or restarted. Runtime, visual, password, lock/unlock and DPMS tests
remain deferred to the user's session restart. This is not fresh-machine or
cross-GPU validation of the published bundle.

## 2026-10-28 source update

Selected live ShojiWM/Quickshell sources were compared with the existing public
copy. Personal paths, account gates, empty-first presets, neutral artwork and
portable startup scripts were preserved. The public fork's `main` head matched
the new pinned revision when checked with `git ls-remote`.

The source diff, new icon references, runtime-state exclusions and third-party
notices were inspected. No automated privacy checker, tests, build, lint,
typecheck, installer run or graphical check was executed for this update.
PAM authentication, unlock and DPMS recovery in the sanitized copy remain unverified.
Wallpaper patch provenance and earlier local validation are described separately
in [wallpaper-engine.md](wallpaper-engine.md); those results are not a test of this bundle.

## 2026-10-04 source update

Selected live desktop source was exported into the publication tree. The privacy
guard was run on that tree; personal paths, profile links/tags, application pins,
private music catalogs and saved wallpaper choices were excluded. Generated clock
sprite sheets have an explicit file allowlist. Account collectors retain their
opt-in gates, including inside Home Zone. No new build, lint, typecheck, installer
test or graphical test was run for this update. The earlier checks below apply
to the September snapshot, not automatically to the new source.

The compositor snapshot is pinned separately in `sources.json`. Its provenance
is the installed local desktop; publishing it does not establish clean-machine
or cross-GPU compatibility.

## 2026-09-28 packaging checks

Packaging checks performed on 2026-09-28, with permission, without changing the
running desktop or invoking account integrations:

| Check | Result |
| --- | --- |
| Installer preview in an empty temporary home | No files written |
| Full install into temporary home with a space in its path | Files copied, home-specific paths rendered, runtime link created |
| Second install into that temporary home | Existing configs backed up; local integration flags preserved; backup manifest retained |
| Three Qt fragment shaders | Compiled with the installed Qt 6 `qsb` |
| Walker patch against exact clean upstream commit | Applies; all four resulting Rust files match the working customized source |
| 15 TypeScript/TSX source files | Parsed with Bun's TypeScript/TSX transpiler; this is syntax checking, not API type checking |
| Python, shell, Node adapter, JSON, TOML, XML/SVG | Syntax/parse checks passed |
| 41 QML files with Qt 6 qmllint | No error-level diagnostics; warning-level diagnostics remain and match the original live sources |
| Five Python/Node collectors without opt-in | Refuse execution before querying accounts or reading session data |
| Two published skills | Skill frontmatter/structure validation passed |
| Publication privacy guard | No findings in the selected publication files; source paths, endpoints and binary provenance also reviewed |
| Grain PNG metadata | Only IHDR/IDAT/IEND chunks; no screenshot or embedded textual metadata |

The QML warnings include incomplete Quickshell type metadata (`PanelWindow`,
`QProcess::ExitStatus`, `UntypedObjectModel`, `FileViewAdapter`) and existing dynamic
property/layout warnings. They are not represented as a clean lint pass, nor as
proof of a runtime failure. The sanitized copy introduced no additional diagnostics
in the comparison. No live shell was launched for this packaging check.

Not performed: building the published ShojiWM integration revision, rebuilding
Walker during packaging, installing system packages, logging into a clean user
desktop, checking every GPU/output combination, or connecting real provider accounts.
The original working desktop provides provenance, not a substitute for testing the
sanitized configuration on a fresh machine.

Reproduce the isolated checks after installing prerequisites and compiling shaders:

```bash
python3 dotfiles/scripts/check-install.py
python3 dotfiles/scripts/check-public.py
```

For a full user acceptance check, log into the installed desktop deliberately and
check terminal/launcher, focus, tiling, minimize/restore/close, both output scaling
and workspace movement, all three presets, simultaneous wallpaper/layout selection,
notification/tray interaction and recording. Enable account integrations only with
your own credentials when you are ready to exercise those optional paths.
