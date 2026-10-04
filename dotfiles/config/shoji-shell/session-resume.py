#!/usr/bin/env python3
"""Read local session metadata; never start or modify an agent session."""
import datetime as dt
import heapq
import json
import math
import os
from pathlib import Path
import shlex
import sqlite3
import sys
import tempfile
import uuid


HOME = Path.home()
COMMANDS = {"codex": ["codex", "resume"], "kimi": ["kimi", "--session"], "grok": ["grok", "--resume"]}
ARCHIVE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "shoji-shell/session-archive.sqlite3"


def read_archive(path=ARCHIVE):
    if not path.exists():
        return set()
    connection = sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True, timeout=2)
    try:
        return set(connection.execute("SELECT provider, session_id FROM archived_sessions"))
    finally:
        connection.close()


def set_archived(provider, session_id, archived, path=ARCHIVE):
    if provider not in COMMANDS or entry(provider, session_id, "", "/", 1) is None:
        raise ValueError("Invalid session")
    path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(path, timeout=2)
    try:
        with connection:
            connection.execute("CREATE TABLE IF NOT EXISTS archived_sessions "
                               "(provider TEXT, session_id TEXT, PRIMARY KEY (provider, session_id))")
            connection.execute("INSERT OR IGNORE INTO archived_sessions VALUES (?, ?)" if archived else
                               "DELETE FROM archived_sessions WHERE provider = ? AND session_id = ?",
                               (provider, session_id))
    finally:
        connection.close()


def entry(provider, session_id, title, cwd, updated):
    if not isinstance(session_id, str) or not isinstance(cwd, str):
        return None
    bare_id = session_id.removeprefix("session_") if provider == "kimi" else session_id
    try:
        if str(uuid.UUID(bare_id)) != bare_id.lower():
            return None
        if isinstance(updated, str):
            updated = dt.datetime.fromisoformat(updated.replace("Z", "+00:00")).timestamp()
        if not math.isfinite(updated) or updated <= 0:
            return None
        timestamp = dt.datetime.fromtimestamp(updated, dt.timezone.utc).isoformat()
    except (ValueError, TypeError, OverflowError, OSError):
        return None
    if not Path(cwd).is_absolute() or any(ord(char) < 32 or ord(char) == 127 for char in cwd):
        return None
    return {
        "id": session_id,
        "title": " ".join(str(title or "Без названия").split())[:240],
        "project": Path(cwd).name or cwd,
        "updatedAt": timestamp,
        "command": shlex.join(["cd", "--", cwd]) + " && " + shlex.join(COMMANDS[provider] + [session_id]),
    }


def recent(entries, excluded=()):
    return heapq.nlargest(5, (value for value in entries if value and value["id"] not in excluded),
                          key=lambda value: value["updatedAt"])


def codex_sessions():
    database = Path(os.environ.get("CODEX_HOME", HOME / ".codex")) / "state_5.sqlite"
    if not database.is_file():
        return
    connection = sqlite3.connect(database.resolve().as_uri() + "?mode=ro", uri=True, timeout=2)
    try:
        for session_id, title, cwd, updated, rollout in connection.execute("""
            SELECT id, COALESCE(NULLIF(name, ''), title), cwd,
                   COALESCE(updated_at_ms, updated_at * 1000), rollout_path
            FROM threads
            WHERE archived = 0 AND source IN ('cli', 'vscode', 'mcp')
            ORDER BY updated_at DESC
        """):
            if Path(rollout).is_file():
                yield entry("codex", session_id, title, cwd, updated / 1000)
    finally:
        connection.close()


def file_sessions(provider, errors):
    base = HOME / (".kimi-code" if provider == "kimi" else ".grok") / "sessions"
    pattern = "wd_*/*/state.json" if provider == "kimi" else "*/*/summary.json"
    for path in base.glob(pattern):
        try:
            value = json.loads(path.read_text())
            if provider == "kimi":
                if value.get("archived") or "main" not in value.get("agents", {}):
                    continue
                yield entry(provider, value.get("id"), value.get("title") or value.get("lastPrompt"),
                            value.get("cwd"), value.get("updatedAt", 0) / 1000)
            else:
                if value.get("session_kind") == "headless" or value.get("archived"):
                    continue
                info = value.get("info", {})
                yield entry(provider, info.get("id"), value.get("generated_title") or value.get("session_summary"),
                            info.get("cwd"), value.get("last_active_at") or value.get("updated_at"))
        except FileNotFoundError:
            continue  # A session may be removed during the scan.
        except (OSError, ValueError, TypeError, AttributeError):
            errors.append("Часть сессий не удалось прочитать")


def collect():
    result = {}
    try:
        archived = read_archive()
    except (OSError, sqlite3.Error):
        return {provider: {"sessions": [], "error": "Не удалось прочитать архив виджета"} for provider in COMMANDS}
    for provider in COMMANDS:
        errors = []
        try:
            sessions = recent(codex_sessions() if provider == "codex" else file_sessions(provider, errors),
                              {session_id for agent, session_id in archived if agent == provider})
            result[provider] = {"sessions": sessions, "error": errors[0] if errors else ""}
        except (OSError, sqlite3.Error, ValueError, TypeError):
            result[provider] = {"sessions": [], "error": "Не удалось прочитать сессии"}
    return result


def self_check():
    session_id = "01a0e407-de90-7d61-af9c-1d49a0a4008c"
    cwd = "/tmp/проект ' $(echo unsafe)"
    for provider, command in COMMANDS.items():
        identifier = "session_" + session_id if provider == "kimi" else session_id
        value = entry(provider, identifier, "Задача\nс пробелами", cwd, 1790540000)
        assert shlex.split(value["command"]) == ["cd", "--", cwd, "&&", *command, identifier]
        assert value["title"] == "Задача с пробелами"
        assert entry(provider, identifier + ";echo unsafe", "", cwd, 1790540000) is None
        assert entry(provider, identifier, "", "/tmp/bad\npath", 1790540000) is None
    values = [entry("codex", session_id, str(n), "/tmp", 1790540000 + n) for n in (2, 5, 0, 6, 1, 4, 3)]
    assert [value["title"] for value in recent([None, *values])] == ["6", "5", "4", "3", "2"]
    with tempfile.TemporaryDirectory() as directory:
        archive = Path(directory) / "archive.sqlite3"
        assert read_archive(archive) == set()
        set_archived("codex", session_id, True, archive)
        set_archived("grok", session_id, True, archive)
        set_archived("codex", session_id, True, archive)
        assert read_archive(archive) == {("codex", session_id), ("grok", session_id)}
        assert recent(values, {session_id}) == []
        set_archived("codex", session_id, False, archive)
        assert read_archive(archive) == {("grok", session_id)}
        other = dict(values[0], id="01a0e407-de90-7d61-af9c-1d49a0a4008d")
        assert recent([*values, other], {session_id}) == [other]
    print("Session command quoting and recency: OK")


if __name__ == "__main__":
    if "--self-check" not in sys.argv and os.environ.get("SHOJI_ENABLE_SESSIONS") != "1":
        sys.exit("Session integration is disabled; opt in locally first")
    if "--self-check" in sys.argv:
        self_check()
    elif len(sys.argv) == 4 and sys.argv[1] in ("--archive", "--restore"):
        try:
            set_archived(sys.argv[2], sys.argv[3], sys.argv[1] == "--archive")
        except (OSError, sqlite3.Error, ValueError):
            print("Не удалось сохранить архив виджета", file=sys.stderr)
            sys.exit(1)
    else:
        print(json.dumps(collect(), ensure_ascii=False))
