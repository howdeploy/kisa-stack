# Optional voice widget and chat selection

The bundle contains the panel entry, service indicators, dictation-mode buttons,
recent-chat selector and a transcript-free IPC adapter. It does not contain the
author's voice installation, account files, speech models, Home Assistant token,
speaker pairing, service state or selected chat.

Enable it only in the **installed**, private `shoji-shell/integrations.env`:

```bash
SHOJI_ENABLE_VOICE=1
SHOJI_VOICE_SOCKET="$XDG_RUNTIME_DIR/shoji-voice/input.sock"
# Optional health-unit names for your own installation:
# SHOJI_VOICE_INPUT_UNIT=alice-local-voice.service
# SHOJI_VOICE_SPEECH_UNIT=alice-agent-speech.service
```

Restart the shell when ready to load environment changes. The top-bar button opens
the existing voice panel. The additional “Ввод и голос” wallpaper preset places
the desktop mode/status widget on the primary output. All earlier presets and
the initial empty preset remain. With the flag off, the widget and adapter do not
query sessions, systemd units or the voice socket.

You need your **own running voice router** implementing the protocol below.
The desktop does not install or start a speech recognition/synthesis engine,
connect a speaker or run an agent. A missing router shows unavailable state.
This is the same integration boundary as other optional service widgets.

## Local router protocol, version 1

Use a user-private UNIX socket (mode 0600 in a private runtime directory). One
connection carries one JSON request terminated by a newline and one JSON response.
The adapter uses only these commands:

| Request | Response |
| --- | --- |
| `{"command":"status"}` | Object with `version: 1`, `mode: "codex"` or `"window"`, and optional `thread_id` plus health fields |
| `{"command":"threads"}` | `{"threads":[{"id":"demo-chat","name":"Demo"}]}`; return the newest entries first |
| `{"command":"set_mode","mode":"window"}` | Status object with `version: 1`, or an `error` field |
| `{"command":"select_thread","thread_id":null}` | Status object; null disconnects the agent destination |

Chat selection also accepts a string `thread_id`. The panel shows at most seven
recent chats, includes “Без Codex”, and never resumes or sends a prompt to one.
Mode selection chooses dictation delivery to the active field or the selected
agent; the router owns actual delivery and must honour session-lock state.
The adapter never imports a backend checkout or uses its Python virtual environment.

Optional status fields match the existing local router: `speaker_connected`,
`hardware_mic_enabled`, `asr_ready`, `voice_ready`, `codex_connected`, `codex_error`,
`home_assistant: {connected, checked_at}` and
`speech: {updated_at, thread_id, control_ready, provider_connected, codex_connected,
codex_error}`. Timestamps are Unix seconds. Stale/missing information remains
unknown; it is never presented as confirmed readiness.

The panel keeps returned chat titles and health in memory. Actions use explicit
argv/JSON, not shell interpolation. No transcript, credential or selected session
is shipped in the public tree. Models, service setup and provider authentication
belong to your external voice installation.

## Source checks

`python3 dotfiles/scripts/check-voice-integration.py` checks opt-in and the actual
adapter against a disposable local stub socket, including chat disconnect. It
does not connect to real services or an agent. This publication has no new voice
hardware or graphical acceptance run.
