"""24 spectrum bands from browser or MateEngine playback; never a microphone."""
import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import sys
import time

import numpy as np

RATE, SIZE, BARS = 24000, 1024, 24
WINDOW = np.hanning(SIZE)
# Keep 24 nonempty logarithmic bands, including low frequencies.
EDGES = np.geomspace(1, SIZE // 2, BARS + 1).astype(int)
for i in range(1, len(EDGES)):
    EDGES[i] = max(EDGES[i], EDGES[i - 1] + 1)


def bands(samples):
    power = np.abs(np.fft.rfft(np.nan_to_num(samples, nan=0, posinf=0, neginf=0) * WINDOW)) / (WINDOW.sum() / 2)
    values = np.array([np.max(power[a:b]) for a, b in zip(EDGES[:-1], EDGES[1:])])
    return np.clip((20 * np.log10(np.maximum(values, 1e-8)) + 65) / 65, 0, 1)


def descendant(pid, owner):
    for _ in range(32):
        if pid == owner:
            return True
        if pid <= 1:
            break
        try:
            pid = int(Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[1])
        except (OSError, ValueError, IndexError):
            break
    return False


def pulse_list(kind):
    return json.loads(subprocess.check_output(["pactl", "-f", "json", "list", kind], timeout=2, stderr=subprocess.DEVNULL))


def media_owner(pid):
    browsers = {"brave", "brave-browser", "chrome", "chromium", "chromium-browser", "firefox", "firefox-bin", "vivaldi-bin", "msedge", "opera"}
    owner = 0
    kind = ""
    for _ in range(32):
        if pid <= 1:
            break
        try:
            binary = Path(os.readlink(f"/proc/{pid}/exe")).name
            if binary in browsers:
                owner = pid
                kind = "browser"
            elif binary == "MateEngineX.x86_64":
                owner = pid
                kind = "mateengine"
            pid = int(Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[1])
        except (OSError, ValueError, IndexError):
            break
    return owner, kind


def targets(owner):
    matches = []
    for stream in pulse_list("sink-inputs"):
        try:
            pid = int(stream.get("properties", {}).get("application.process.id", 0))
        except (TypeError, ValueError):
            continue
        if stream.get("corked", True) or stream.get("mute", False):
            continue
        stream_owner, kind = media_owner(pid)
        if owner:
            stream_owner = owner if descendant(pid, owner) else 0
            kind = kind or "browser"
        if stream_owner:
            matches.append((stream, stream_owner, kind))
    # ponytail: a shared browser stream may mix tabs; exact tab isolation needs a browser capture bridge.
    if not matches:
        return []
    monitors = {sink["index"]: sink["monitor_source"] for sink in pulse_list("sinks")
                if isinstance(sink.get("monitor_source"), str)}
    return [(stream["index"], monitors[stream["sink"]], stream_owner, kind)
            for stream, stream_owner, kind in matches if stream["sink"] in monitors]


def mateengine_track(pid):
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if not runtime or pid <= 1:
        return {}
    path = Path(runtime) / f"mateengine-now-playing-{pid}.json"
    try:
        if not 0 <= time.time() - path.stat().st_mtime < 3 or path.stat().st_size > 16384:
            return {}
        track = json.loads(path.read_text())
        if track.get("pid") != pid or not isinstance(track.get("playing"), bool):
            return {}
        if not all(isinstance(track.get(key), str) for key in ("title", "artist", "artwork")):
            return {}
        if track["artwork"] and not track["artwork"].startswith("file:///"):
            track["artwork"] = ""
        return track
    except (OSError, ValueError, TypeError):
        return {}


def run(owner):
    captures = {}
    current = None
    ambiguous = False
    selector = selectors.DefaultSelector()
    silence = np.zeros(BARS)
    next_scan = next_emit = 0
    track_cache = {}
    track_pid = 0
    next_track = 0

    def emit(now):
        nonlocal track_cache, track_pid, next_track
        state = captures.get(current)
        available = state is not None and now - state["last_audio"] < 1
        smoothed = state["smoothed"] if available else silence
        pid = current[2] if current and current[3] == "mateengine" else 0
        if pid != track_pid or now >= next_track:
            track_pid, next_track = pid, now + 0.5
            track_cache = mateengine_track(pid) if pid else {}
        print(json.dumps({"pid": current[2] if current else 0, "ambiguous": ambiguous,
                          "source": current[3] if current else "",
                          "available": available, "bars": smoothed.round(3).tolist(),
                          "track": track_cache}), flush=True)

    def close_capture(source):
        capture = captures.pop(source)["process"]
        selector.unregister(capture.stdout)
        capture.terminate()
        try:
            capture.wait(timeout=1)
        except subprocess.TimeoutExpired:
            capture.kill()
            capture.wait()
        capture.stdout.close()

    def terminate(_signum, _frame):
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, terminate)
    signal.signal(signal.SIGINT, terminate)
    try:
        while True:
            now = time.monotonic()
            previous = (current, ambiguous)
            if now >= next_scan:
                next_scan = now + 2
                try:
                    wanted = targets(owner)
                except (OSError, ValueError, KeyError, subprocess.SubprocessError):
                    wanted = []
                for source in list(captures):
                    if source not in wanted:
                        close_capture(source)
                for source in wanted:
                    if source not in captures:
                        capture = subprocess.Popen([
                            "parec", "--raw", "--format=float32le", f"--rate={RATE}", "--channels=1",
                            "--latency-msec=50", f"--monitor-stream={source[0]}", f"--device={source[1]}",
                            "--client-name=Shoji Music Spectrum", "--stream-name=Music spectrum",
                        ], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
                        captures[source] = {"process": capture, "buffer": bytearray(),
                                            "smoothed": np.zeros(BARS), "last_audio": 0, "last_signal": 0}
                        selector.register(capture.stdout, selectors.EVENT_READ, source)
            events = selector.select(timeout=0.1)
            for key, _ in events:
                state = captures[key.data]
                chunk = os.read(key.fd, SIZE * 4)
                if not chunk:
                    close_capture(key.data)
                    continue
                buffer = state["buffer"]
                buffer.extend(chunk)
                while len(buffer) >= SIZE * 4:
                    samples = np.frombuffer(bytes(buffer[:SIZE * 4]), dtype="<f4")
                    del buffer[:SIZE * 4]
                    levels = bands(samples)
                    state["last_audio"] = time.monotonic()
                    if np.any(levels > 0):
                        state["last_signal"] = state["last_audio"]
                    state["smoothed"][:] = np.maximum(levels, state["smoothed"] * 0.78)
            now = time.monotonic()
            responsive = [source for source, state in captures.items() if now - state["last_audio"] < 1]
            # An uncorked stream can be silent. Hold activity briefly across beats.
            audible = [source for source in responsive if now - captures[source]["last_signal"] < 0.75]
            ambiguous = len(audible) > 1
            if len(responsive) != len(captures) or ambiguous:
                current = None
            elif len(captures) == 1:
                current = next(iter(captures))
            elif len(audible) == 1:
                current = audible[0]
            elif current not in captures:
                current = None
            if now >= next_emit or (current, ambiguous) != previous or any(key.data == current for key, _ in events):
                emit(now)
                next_emit = now + 1
    finally:
        for source in list(captures):
            close_capture(source)
        selector.close()


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-check"]:
        assert np.all(bands(np.zeros(SIZE)) == 0)
        low = bands(np.sin(2 * np.pi * 100 * np.arange(SIZE) / RATE) * 0.5)
        high = bands(np.sin(2 * np.pi * 5000 * np.arange(SIZE) / RATE) * 0.5)
        assert len(low) == BARS and low.argmax() < high.argmax()
        assert np.isfinite(bands(np.full(SIZE, np.nan))).all()
        assert descendant(os.getpid(), os.getpid()) and not descendant(0, os.getpid())
        print("Spectrum: silence, frequency separation and process ownership OK")
    elif sys.argv[1:] == ["--auto"] or (len(sys.argv) == 2 and sys.argv[1].isdigit() and int(sys.argv[1]) > 1):
        try:
            run(0 if sys.argv[1] == "--auto" else int(sys.argv[1]))
        except BrokenPipeError:
            sys.stdout = open(os.devnull, "w")
    else:
        sys.exit("Usage: music-spectrum.py --auto | BROWSER_PID | --self-check")
