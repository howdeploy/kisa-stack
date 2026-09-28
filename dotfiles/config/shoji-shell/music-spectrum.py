"""24 spectrum bands from one browser sink input; never the default microphone."""
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


def target(owner):
    matches = []
    for stream in pulse_list("sink-inputs"):
        try:
            pid = int(stream.get("properties", {}).get("application.process.id", 0))
        except (TypeError, ValueError):
            continue
        if not stream.get("corked", True) and not stream.get("mute", False) and descendant(pid, owner):
            matches.append(stream)
    # ponytail: a shared browser stream may mix tabs; exact tab isolation needs a browser capture bridge.
    if len(matches) != 1:
        return None
    stream = matches[0]
    for sink in pulse_list("sinks"):
        if sink["index"] == stream["sink"] and isinstance(sink.get("monitor_source"), str):
            return (stream["index"], sink["monitor_source"])
    return None


def run(owner):
    capture = None
    current = None
    selector = selectors.DefaultSelector()
    buffer = bytearray()
    smoothed = np.zeros(BARS)
    next_scan = last_audio = 0

    def emit(available):
        print(json.dumps({"pid": owner, "available": available, "bars": smoothed.round(3).tolist()}), flush=True)

    def close_capture():
        nonlocal capture
        if capture is not None:
            selector.unregister(capture.stdout)
            capture.terminate()
            try:
                capture.wait(timeout=1)
            except subprocess.TimeoutExpired:
                capture.kill()
                capture.wait()
            capture.stdout.close()
            capture = None
        buffer.clear()
        smoothed.fill(0)

    def terminate(_signum, _frame):
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, terminate)
    signal.signal(signal.SIGINT, terminate)
    try:
        while True:
            now = time.monotonic()
            if now >= next_scan:
                next_scan = now + 2
                try:
                    wanted = target(owner)
                except (OSError, ValueError, KeyError, subprocess.SubprocessError):
                    wanted = None
                if wanted != current or (wanted and capture is None):
                    close_capture()
                    current = wanted
                    if current:
                        capture = subprocess.Popen([
                            "parec", "--raw", "--format=float32le", f"--rate={RATE}", "--channels=1",
                            "--latency-msec=50", f"--monitor-stream={current[0]}", f"--device={current[1]}",
                            "--client-name=Shoji Music Spectrum", "--stream-name=Music spectrum",
                        ], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
                        selector.register(capture.stdout, selectors.EVENT_READ)
                        last_audio = now
                if capture is None:
                    emit(False)
            events = selector.select(timeout=0.1)
            for key, _ in events:
                chunk = os.read(key.fd, SIZE * 4)
                if not chunk:
                    close_capture()
                    emit(False)
                    break
                last_audio = time.monotonic()
                buffer.extend(chunk)
                while len(buffer) >= SIZE * 4:
                    samples = np.frombuffer(bytes(buffer[:SIZE * 4]), dtype="<f4")
                    del buffer[:SIZE * 4]
                    smoothed[:] = np.maximum(bands(samples), smoothed * 0.78)
                    emit(True)
            if capture is not None and time.monotonic() - last_audio > 1:
                smoothed.fill(0)
                emit(False)
                last_audio = time.monotonic()
    finally:
        close_capture()
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
    elif len(sys.argv) == 2 and sys.argv[1].isdigit() and int(sys.argv[1]) > 1:
        try:
            run(int(sys.argv[1]))
        except BrokenPipeError:
            sys.stdout = open(os.devnull, "w")
    else:
        sys.exit("Usage: music-spectrum.py BROWSER_PID | --self-check")
