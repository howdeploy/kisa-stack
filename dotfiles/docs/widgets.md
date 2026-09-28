# Optional widget integrations

The appearance works without any account. All account/session integrations and
weather are **disabled by default**, including on a machine whose CLIs are already
authenticated. Presets define placement; `Settings.enabled()` is an independent
permission gate before widget loaders become active. Python/Node collectors also
refuse direct execution unless their own enable flag is set.

Copy the example into the **installed**, local shell directory:

```bash
cp "${XDG_CONFIG_HOME:-$HOME/.config}/shoji-shell/integrations.env.example" \
   "${XDG_CONFIG_HOME:-$HOME/.config}/shoji-shell/integrations.env"
chmod 600 "${XDG_CONFIG_HOME:-$HOME/.config}/shoji-shell/integrations.env"
```

Edit only the flags you want, then restart the shell when ready. `scripts/start-shell`
sources this trusted shell file before starting Quickshell. Never source a stranger's
integration file. It should contain flags, paths and optional weather locations,
not API keys. Authentication remains owned by each locally installed CLI.

| Flag | Prerequisites and access after opt-in |
| --- | --- |
| `SHOJI_ENABLE_GITHUB=1` | `gh` logged into **your** account; reads notifications, PRs, issues and discussion replies. Does not mark notifications read. Writes a local cache. |
| `SHOJI_ENABLE_VAST=1` | `vastai` configured for **your** account; reads balance, rentals, instance/volume counts and billing. Does not rent, stop or delete resources. Writes a local cache. |
| `SHOJI_ENABLE_LIMITS=1` | Node.js and your installed/authenticated Codex, Grok and/or Kimi CLIs; queries quotas, spawning their local protocol adapters. Missing providers show unavailable. CLI token refresh may update the CLI's own credential store. |
| `SHOJI_ENABLE_SESSIONS=1` | Your local Codex/Kimi/Grok session stores; reads titles and working-directory metadata. Clicking a session copies its resume command using `wl-copy`; it does not run it. Widget archiving writes its own local SQLite index. |
| `SHOJI_ENABLE_HERMES=1` | A compatible Hermes checkout/venv with `tui_gateway.entry`; starts only when you submit a message. It is a real agent with your configured tools, permissions and model costs. |
| `SHOJI_ENABLE_WEATHER=1` | `SHOJI_WEATHER_CITIES` with exactly two `[id,name,latitude,longitude]` entries. Sends those coordinates to Open-Meteo; no API key is required. |

Hermes uses `${HOME}/.hermes/hermes-agent` by default; override `SHOJI_HERMES_ROOT`.
Its adapter expects JSON-RPC methods such as `session.create`, `prompt.submit`,
`session.interrupt` and approval/secret response messages. An arbitrary Hermes
release is not guaranteed to implement this protocol. The desktop bundle does
not install an agent, enable tools or copy any model configuration for you.

The limits and session adapters track particular CLI protocols/schema versions;
those can change independently of the desktop. Check their source when updating
a CLI. A missing quota is not a zero balance. No token is supplied in this repository.

Music uses standard MPRIS metadata from your players. The spectrum uses a local
PipeWire/PulseAudio recording stream when the player exposes a PID, with NumPy
for FFT processing. It does not upload audio. Neko reacts to the music energy.
The author's private music catalog, artwork paths and site-specific adapter are
not included. Track artwork URLs are supplied by the local player.

Local caches and session metadata can contain private repository names, discussion
titles, rental labels and prompts. They are not publication material. Do not copy
`~/.cache/shoji-shell`, `~/.local/state/shoji-shell`, CLI homes or `integrations.env`
back into this repository. Disable integrations before recording a public demo.
