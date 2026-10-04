# Validation record

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
