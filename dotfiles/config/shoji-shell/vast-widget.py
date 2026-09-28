"""Read-only Vast.ai dashboard collector. Never emit raw account data or stderr."""
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from decimal import Decimal
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

CLI = shutil.which("vastai") or str(Path.home() / ".local/bin/vastai")
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "shoji-shell/vast"


def cli(*args):
    result = subprocess.run([CLI, *args, "--raw"], capture_output=True, text=True, timeout=40)
    if result.returncode:
        raise ValueError("CLI unavailable")
    return json.loads(result.stdout)


def money(value):
    if type(value) not in (int, float) or not math.isfinite(value):
        raise ValueError("Invalid amount")
    return Decimal(str(value))


def rows(value):
    if not isinstance(value, list) or not all(isinstance(row, dict) for row in value):
        raise ValueError("Invalid resource list")
    return value


def balance():
    user = cli("show", "user")
    return {"credit": float(money(user["credit"]))}


def instances():
    data = rows(cli("show", "instances"))
    statuses = [str(row.get("actual_status") or row.get("status") or "unknown") for row in data]
    return {"total": len(data), "running": statuses.count("running")}


def volumes():
    return {"total": len(rows(cli("show", "volumes", "--type", "all")))}


def charge_pages(start, end, instance_only=False):
    token = None
    seen_tokens = set()
    received = 0
    for _ in range(100):
        args = ["show", "invoices-v1", "--charges", "--start-date", start,
                "--end-date", str(end), "--limit", "100", "--latest-first"]
        if instance_only:
            args += ["--charge-type", "instance"]
        if token:
            args += ["--next-token", token]
        page = cli(*args)
        if not isinstance(page, dict) or page.get("success") is not True:
            raise ValueError("Billing unavailable")
        batch = rows(page.get("results"))
        received += len(batch)
        next_token = page.get("next_token")
        if not next_token and type(page.get("total")) is int and received != page["total"]:
            raise ValueError("Incomplete billing history")
        yield batch
        if not next_token:
            return
        if not isinstance(next_token, str) or next_token in seen_tokens or not batch:
            raise ValueError("Invalid billing pagination")
        seen_tokens.add(next_token)
        token = next_token
    raise ValueError("Billing pagination limit reached")


def summarize(charges):
    return float(sum((money(row["amount"]) for row in rows(charges)), Decimal(0)))


def recent_row(row):
    source = row.get("source", "")
    if row.get("type") != "instance" or not isinstance(source, str) or not re.fullmatch(r"instance-\d+", source):
        return None
    stamp = row.get("end")
    if type(stamp) not in (int, float) or not math.isfinite(stamp) or stamp <= 0:
        raise ValueError("Invalid billing date")
    metadata = row.get("metadata") or {}
    if not isinstance(metadata, dict):
        raise ValueError("Invalid rental metadata")
    label = metadata.get("label")
    return {"id": source.removeprefix("instance-"),
            "label": label[:120] if isinstance(label, str) and label else source,
            "date": datetime.fromtimestamp(stamp, timezone.utc).strftime("%d.%m"),
            "amount": float(money(row["amount"]))}


def billing():
    now = datetime.now(timezone.utc)
    period = now.strftime("%Y-%m")
    end = int(now.timestamp())
    charges = [row for page in charge_pages(period + "-01", end) for row in page]
    return {"period": period, "total": summarize(charges)}


def rentals():
    end = int(time.time())
    recent = []
    seen = set()
    # Vast treats timestamp 0 as a missing date filter.
    for page in charge_pages("1", end, instance_only=True):
        for row in page:
            rental = recent_row(row)
            if rental and rental["id"] not in seen:
                seen.add(rental["id"])
                recent.append(rental)
            if len(recent) == 3:
                break
        if len(recent) == 3:
            break
    return {"recent": recent}


def cached(kind):
    try:
        payload = json.loads((CACHE / (kind + ".json")).read_text())
        if (isinstance(payload, dict) and payload.get("kind") == kind
                and payload.get("state") == "available"
                and type(payload.get("fetchedAt")) in (int, float)
                and 0 < payload["fetchedAt"] <= time.time() * 1000):
            return payload
    except (OSError, ValueError):
        pass
    return None


def save_cache(payload):
    # Only the same reduced payload sent to QML is persisted, never CLI output.
    temporary = None
    try:
        CACHE.mkdir(parents=True, exist_ok=True, mode=0o700)
        with tempfile.NamedTemporaryFile(mode="w", dir=CACHE, delete=False) as stream:
            temporary = Path(stream.name)
            json.dump(payload, stream, ensure_ascii=False, allow_nan=False)
        temporary.replace(CACHE / (payload["kind"] + ".json"))
    except OSError:
        pass
    finally:
        if temporary is not None:
            try:
                temporary.unlink(missing_ok=True)
            except OSError:
                pass


def collect(kind, action):
    try:
        payload = {"state": "available", **action(), "fetchedAt": int(time.time() * 1000)}
    except (OSError, ValueError, KeyError, TypeError, OverflowError, subprocess.SubprocessError):
        # CLI errors can contain API keys in request URLs. Never forward them.
        payload = {"state": "unavailable"}
    message = {"kind": kind, **payload}
    if message["state"] == "available":
        save_cache(message)
    return message


def refresh(actions, ttl):
    pending = []
    for kind, action in actions:
        previous = cached(kind)
        if previous:
            print(json.dumps(previous, ensure_ascii=False, allow_nan=False), flush=True)
        if (not previous or time.time() * 1000 - previous["fetchedAt"] >= ttl * 1000
                or kind == "billing" and previous.get("period") != datetime.now(timezone.utc).strftime("%Y-%m")):
            pending.append((kind, action))
    with ThreadPoolExecutor(max_workers=3) as pool:
        futures = [pool.submit(collect, kind, action) for kind, action in pending]
        for future in as_completed(futures):
            print(json.dumps(future.result(), ensure_ascii=False, allow_nan=False), flush=True)


def self_check():
    from contextlib import redirect_stdout
    from io import StringIO

    global CACHE
    assert summarize([]) == 0
    assert summarize([{"amount": 10.838, "items": [{"amount": 8.791}]}, {"amount": 1.856}]) == 12.694
    rental = recent_row({"type": "instance", "source": "instance-123", "end": 1790208000,
                         "metadata": {"label": "GPU rental"}, "amount": 10.838})
    assert rental["id"] == "123" and rental["date"] == "24.09"
    assert recent_row({"type": "volume", "source": "volume-123"}) is None
    for invalid in (None, True, float("nan"), "0"):
        try:
            money(invalid)
        except ValueError:
            continue
        raise AssertionError("Invalid amount accepted")
    original_cache = CACHE
    try:
        with tempfile.TemporaryDirectory() as directory:
            CACHE = Path(directory)
            period = datetime.now(timezone.utc).strftime("%Y-%m")
            sample = collect("billing", lambda: {"period": period, "total": 12.694})
            assert cached("billing") == sample
            assert (CACHE / "billing.json").stat().st_mode & 0o777 == 0o600
            def fail():
                raise ValueError("offline")
            assert collect("billing", fail)["state"] == "unavailable"
            assert cached("billing") == sample
            output = StringIO()
            with redirect_stdout(output):
                refresh((("billing", fail), ("rentals", fail)), 900)
            messages = [json.loads(line) for line in output.getvalue().splitlines()]
            assert messages[0] == sample
            assert messages[1] == {"kind": "rentals", "state": "unavailable"}
            # Month rollover refreshes even a recent cache, without waiting for history.
            save_cache({**sample, "period": "2000-01"})
            output = StringIO()
            with redirect_stdout(output):
                refresh((("billing", lambda: {"period": period, "total": 1.5}),), 900)
            messages = [json.loads(line) for line in output.getvalue().splitlines()]
            assert len(messages) == 2 and messages[-1]["total"] == 1.5
            (CACHE / "billing.json").write_text("invalid JSON")
            assert cached("billing") is None
    finally:
        CACHE = original_cache
    print("Vast: totals, cache replay, atomic private files, independent failures and month rollover OK")


if __name__ == "__main__":
    if "--self-check" not in sys.argv and os.environ.get("SHOJI_ENABLE_VAST") != "1":
        sys.exit("Vast integration is disabled; opt in locally first")
    if sys.argv[1:] == ["--self-check"]:
        self_check()
    elif sys.argv[1:] == ["status"]:
        refresh((("account", balance), ("instances", instances), ("volumes", volumes)), 60)
    elif sys.argv[1:] == ["billing"]:
        refresh((("billing", billing), ("rentals", rentals)), 900)
    else:
        sys.exit("Usage: vast-widget.py status | billing | --self-check")
