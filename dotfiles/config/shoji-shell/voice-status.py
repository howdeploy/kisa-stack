#!/usr/bin/env python3
"""Adapt an explicitly enabled, transcript-free local voice IPC for the panel."""
import argparse
import asyncio
import json
import math
import os
from pathlib import Path
import sys
import time

SOCKET = Path(os.environ.get("SHOJI_VOICE_SOCKET") or
              Path(os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}") / "shoji-voice/input.sock")
UNITS = (os.environ.get("SHOJI_VOICE_INPUT_UNIT", "alice-local-voice.service"),
         os.environ.get("SHOJI_VOICE_SPEECH_UNIT", "alice-agent-speech.service"))


def state(value="unknown", detail="Нет данных"):
    return {"state": value, "detail": detail}


def fresh(stamp, now, age):
    return type(stamp) in (int, float) and math.isfinite(stamp) and 0 <= now - stamp <= age


def service_state(unit, *, missing_ipc=False):
    if unit.get("ActiveState") in ("activating", "reloading") or unit.get("SubState") == "auto-restart":
        return state("connecting", "Служба запускается или переподключается")
    if unit.get("LoadState") == "not-found" or unit.get("ActiveState") in ("inactive", "failed", "deactivating"):
        return state("unavailable", "Служба недоступна или остановлена")
    if missing_ipc:
        return state("unavailable", "Голосовой IPC не отвечает")
    return state(detail="Нет свежей телеметрии службы")


def normalize(data, units, now):
    available = isinstance(data, dict) and data.get("version") == 1
    local = service_state(units.get(UNITS[0], {}), missing_ipc=True)
    result = {"available": available, "mode": "", "threadId": "", "speechThreadId": "",
              "ha": state(), "speaker": local, "input": local,
              "speech": service_state(units.get(UNITS[1], {})), "codex": state(), "speechCodex": state()}
    if not available:
        return result
    result["mode"] = data.get("mode") if data.get("mode") in ("codex", "window") else ""
    result["threadId"] = data.get("thread_id") or ""
    ha = data.get("home_assistant") or {}
    if fresh(ha.get("checked_at"), now, 15):
        if ha.get("connected") is True:
            result["ha"] = state("ready", "Локальный API отвечает с авторизацией")
        elif ha.get("connected") is False:
            result["ha"] = state("unavailable", "Локальный API или авторизация недоступны")
    elif ha.get("checked_at") is not None:
        result["ha"] = state(detail="Проверка Home Assistant устарела")

    if data.get("speaker_connected") is True:
        result["speaker"] = state("ready", "Связь с колонкой подтверждена")
    elif data.get("speaker_connected") is False:
        result["speaker"] = state("connecting", "Служба ожидает подключения колонки")
    else:
        result["speaker"] = state()
    if data.get("hardware_mic_enabled") is False:
        result["input"] = state("unavailable", "Микрофон выключен на колонке")
    elif (data.get("speaker_connected") is True and data.get("asr_ready") is True
          and data.get("voice_ready") is True and data.get("hardware_mic_enabled") is True):
        result["input"] = state("ready", "GigaAM, голосовой тракт и микрофон готовы")
    elif data.get("voice_ready") is False or data.get("asr_ready") is False:
        result["input"] = state("connecting", "GigaAM или голосовой тракт подключается")
    else:
        result["input"] = state(detail="Нет полного подтверждения готовности ввода")

    if not result["threadId"]:
        result["codex"] = state("unavailable", "Сессия не выбрана; локальные функции доступны")
    elif data.get("codex_connected") is True:
        result["codex"] = state("ready", "Выбранная сессия загружена; доставка подключена")
    elif data.get("codex_connected") is False:
        result["codex"] = state("unavailable" if data.get("codex_error") else "connecting",
                                "Выбранная сессия недоступна" if data.get("codex_error") else "Подключение к выбранной сессии")

    speech = data.get("speech") or {}
    if fresh(speech.get("updated_at"), now, 10):
        result["speechThreadId"] = speech.get("thread_id") or ""
        if speech.get("control_ready") is False or speech.get("provider_connected") is False:
            result["speech"] = state("connecting", "Подключение локального приёма или провайдера синтеза")
        elif speech.get("control_ready") is True and speech.get("provider_connected") is True:
            if result["speaker"]["state"] == "ready":
                result["speech"] = state("ready", "Локальный приём и транспорт синтеза готовы")
            else:
                result["speech"] = state(result["speaker"]["state"], "Синтез подключён; нет готового соединения с колонкой")
        if not result["threadId"]:
            result["speechCodex"] = state("unavailable", "Агент отключён; прямая озвучка независима от Codex")
        elif result["speechThreadId"] != result["threadId"]:
            result["speechCodex"] = state("connecting", "Озвучка ещё переключается на выбранную сессию")
        elif speech.get("codex_connected") is True:
            result["speechCodex"] = state("ready", "Подписка на выбранную сессию подключена")
        elif speech.get("codex_connected") is False:
            result["speechCodex"] = state("unavailable" if speech.get("codex_error") else "connecting",
                                          "Подписка Codex недоступна" if speech.get("codex_error") else "Подключение подписки Codex")
    return result


async def services():
    process = None
    try:
        process = await asyncio.create_subprocess_exec(
            "systemctl", "--user", "show", *UNITS, "--no-pager",
            "--property=Id,LoadState,ActiveState,SubState",
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
        output, _ = await asyncio.wait_for(process.communicate(), 2)
        if process.returncode:
            return {}
        result = {}
        for block in output.decode().strip().split("\n\n"):
            fields = dict(line.split("=", 1) for line in block.splitlines() if "=" in line)
            if fields.get("Id") in UNITS:
                result[fields["Id"]] = fields
        return result
    except (OSError, TimeoutError, UnicodeError):
        return {}
    finally:
        if process and process.returncode is None:
            process.kill()
            await process.wait()


async def request(command="status", **parameters):
    writer = None
    try:
        async with asyncio.timeout(2 if command == "status" else 20):
            reader, writer = await asyncio.open_unix_connection(SOCKET, limit=1024 * 1024)
            payload = {"command": command, **parameters}
            writer.write(json.dumps(payload).encode() + b"\n")
            await writer.drain()
            response = json.loads(await reader.readline())
            return response if isinstance(response, dict) else {}
    except (OSError, ValueError, TimeoutError):
        return {}
    finally:
        if writer:
            writer.close()
            await writer.wait_closed()


def recent_threads(data):
    rows = data.get("threads")
    if not isinstance(rows, list):
        return {}
    # The existing API sorts by updated_at; never page into older sessions.
    return {"threads": rows[:7]}


def arguments(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", nargs="?", default="status",
                        choices=("status", "threads", "set_mode", "select_thread"))
    parser.add_argument("--mode", choices=("codex", "window"))
    parser.add_argument("--thread-id", help="Local chat ID; empty string disconnects")
    args = parser.parse_args(argv)
    if args.command == "set_mode" and args.mode is None:
        parser.error("set_mode requires --mode")
    if args.command == "select_thread" and args.thread_id is None:
        parser.error("select_thread requires --thread-id")
    return args


async def main():
    args = arguments(sys.argv[1:])
    enabled = os.environ.get("SHOJI_ENABLE_VOICE") == "1"
    if args.command in ("set_mode", "select_thread"):
        parameters = {"mode": args.mode} if args.command == "set_mode" else {"thread_id": args.thread_id or None}
        reply = await request(args.command, **parameters) if enabled else {}
        ok = reply.get("version") == 1 and not reply.get("error")
        print(json.dumps({"version": 1} if ok else {"error": "Voice integration is disabled or the local router did not confirm the change."}))
        return 0 if ok else 1
    if args.command == "threads":
        result = recent_threads(await request("threads")) if enabled else {"threads": []}
    else:
        data, units = await asyncio.gather(request(), services()) if enabled else ({}, {})
        result = normalize(data, units, time.time())
    print(json.dumps(result, ensure_ascii=False))
    return 0


def self_check():
    data = {"version": 1, "mode": "window", "speaker_connected": True,
            "asr_ready": True, "voice_ready": True, "hardware_mic_enabled": True,
            "codex_connected": False, "thread_id": None,
            "home_assistant": {"connected": True, "checked_at": 99},
            "speech": {"updated_at": 99, "control_ready": True, "provider_connected": True}}
    result = normalize(data, {}, 100)
    assert result["input"]["state"] == result["speech"]["state"] == "ready"
    assert result["codex"]["state"] == "unavailable"
    assert normalize(dict(data, hardware_mic_enabled=False), {}, 100)["input"]["state"] == "unavailable"
    assert normalize(data, {}, 120)["ha"]["state"] == "unknown"
    assert normalize(data, {}, 120)["speech"]["state"] == "unknown"
    assert normalize({}, {}, 100)["input"]["state"] == "unavailable"
    assert service_state({"ActiveState": "active"})["state"] == "unknown"
    assert service_state({"ActiveState": "activating"})["state"] == "connecting"
    rows = [{"id": str(n)} for n in range(20)]
    assert recent_threads({"threads": rows}) == {"threads": rows[:7]}
    assert recent_threads({}) == {}
    assert arguments([]).command == "status"
    assert arguments(["set_mode", "--mode", "window"]).mode == "window"
    assert arguments(["select_thread", "--thread-id", ""]).thread_id == ""
    print("Voice status classification: OK")


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-check"]:
        self_check()
    else:
        sys.exit(asyncio.run(main()))
