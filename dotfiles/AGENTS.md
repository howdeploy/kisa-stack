# Working on these dotfiles

Read `README.md`, then the relevant page in `docs/`. `sources.json` pins the public
source dependencies. The expected compositor is howdeploy/ShojiWM's integration
branch, not fork `main` or an arbitrary upstream build.

- Keep publication source and installed configuration separate. Ask which is the
  target if the user's request is unclear; do not silently modify both.
- Never copy a home directory, full `.config`, CLI auth files, browser profiles,
  caches, logs, session databases or integration settings into this tree.
- Preserve opt-in gates in `Settings.qml`, all collector entrypoints and Hermes.
  Do not enable an account integration simply because a local CLI is authenticated.
- Do not put API keys/passwords in app launch arguments, examples, fixtures or
  Git history. Use the installing user's CLI credential stores after authorization.
- Preserve the three preset sets and the empty preset first. A layout change can
  alter membership as well as position. Wallpaper and preset selections apply together.
- Before changing animations, follow events, capture lifetime, progress, visibility
  and input. Keep outgoing widget snapshots and CSD/SSD/fullscreen behavior intact.
- Compositor GLSL and Qt GLSL have different ABIs. See `docs/shaders.md`; do not
  compile compositor shaders with `qsb` or paste Shadertoy entrypoints unchanged.
- The launcher theme requires the patch in `patches/walker/`; retain native app-icon
  loading and explicit application/script tags. Do not assume stock Walker is enough.
- Shell scripts are user-level unless documented otherwise. Do not run an installer,
  restart services, reload the compositor or manipulate windows without permission
  appropriate to the user's request. Existing session authorization still applies.
- Run checks only when authorized. Use `--target-home` for an isolated installer
  check; never test installation over a working desktop. Separate source checks,
  shader compilation, live rendering and user validation in the handoff.
- Before publication, inspect the exact staged paths and run the privacy checker
  on index blobs. Keep GitHub prose in English. Preserve component licenses and
  attribution; do not declare all copied third-party material to be MIT.

For reusable workflows, see `../skills/shojiwm/SKILL.md` and
`../skills/shoji-shaders/SKILL.md`, relative to this directory. No private Wiki is needed.
