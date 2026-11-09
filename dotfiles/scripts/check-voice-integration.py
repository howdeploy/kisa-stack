#!/usr/bin/env python3
"""Check opt-in and voice IPC against a disposable local stub, never real services."""
import asyncio
from contextlib import redirect_stdout
import importlib.util
from io import StringIO
import json
import os
from pathlib import Path
import sys
import tempfile
from unittest.mock import patch

source = Path(__file__).resolve().parents[1] / "config/shoji-shell/voice-status.py"
spec = importlib.util.spec_from_file_location("voice_status", source)
voice = importlib.util.module_from_spec(spec)
spec.loader.exec_module(voice)


async def check():
    async def forbidden(*args, **kwargs):
        raise AssertionError("Disabled integration accessed a service")

    with patch.dict(os.environ, {"SHOJI_ENABLE_VOICE": "0"}), patch.object(voice, "request", forbidden), patch.object(voice, "services", forbidden):
        for args, expected in [([], 0), (["set_mode", "--mode", "window"], 1)]:
            output = StringIO()
            with patch.object(sys, "argv", [str(source), *args]), redirect_stdout(output):
                assert await voice.main() == expected
            result = json.loads(output.getvalue())
            assert result.get("available") is False if not args else "error" in result

    requests = []
    async def control(reader, writer):
        request = json.loads(await reader.readline())
        requests.append(request)
        reply = {"threads": [{"id": "demo-chat", "name": "Demo"}]} if request["command"] == "threads" else {"version": 1}
        writer.write(json.dumps(reply).encode() + b"\n")
        await writer.drain()
        writer.close()
        await writer.wait_closed()

    with tempfile.TemporaryDirectory(prefix="shoji-voice-check-") as directory:
        with patch.object(voice, "SOCKET", Path(directory) / "input.sock"):
            server = await asyncio.start_unix_server(control, path=voice.SOCKET)
            async with server:
                with patch.dict(os.environ, {"SHOJI_ENABLE_VOICE": "1"}):
                    for args in (["set_mode", "--mode", "window"],
                                 ["select_thread", "--thread-id", ""],
                                 ["select_thread", "--thread-id", "demo-chat"], ["threads"]):
                        output = StringIO()
                        with patch.object(sys, "argv", [str(source), *args]), redirect_stdout(output):
                            assert await voice.main() == 0
                        result = json.loads(output.getvalue())
                        if args[0] == "threads":
                            assert result["threads"][0]["id"] == "demo-chat"
                        else:
                            assert result == {"version": 1}
    assert requests == [
        {"command": "set_mode", "mode": "window"},
        {"command": "select_thread", "thread_id": None},
        {"command": "select_thread", "thread_id": "demo-chat"},
        {"command": "threads"},
    ]
    print("Voice opt-in, mode change, chat selection/disconnect and recent-chat IPC: OK")


if __name__ == "__main__":
    voice.self_check()
    asyncio.run(check())
