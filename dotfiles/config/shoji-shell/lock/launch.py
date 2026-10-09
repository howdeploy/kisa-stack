#!/usr/bin/env python3
"""Start the independent Shoji locker, or inspect/preview it without locking."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import time
from urllib.parse import unquote, urlparse


SOURCE = Path(__file__).resolve().parent
PAM_DIRECTORY = Path("/etc/pam.d")


def private_runtime():
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", ""))
    if not runtime.is_absolute() or runtime.stat().st_uid != os.getuid():
        raise RuntimeError("Нет доступного каталога текущей сессии XDG_RUNTIME_DIR.")
    directory = runtime / "shoji-lock"
    directory.mkdir(mode=0o700, exist_ok=True)
    info = directory.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid():
        raise RuntimeError("Некорректный каталог shoji-lock.")
    directory.chmod(0o700)
    return directory


def pam_configuration(runtime):
    # Prefer distro-managed password-only policy. Never silently use login's
    # session/TTY policy, nor a service that can succeed without a password.
    for service in ("shoji-lock", "omarchy-lock-password", "swaylock", "hyprlock"):
        if (PAM_DIRECTORY / service).is_file():
            return str(PAM_DIRECTORY), service
    policy = PAM_DIRECTORY
    if not all((policy / name).is_file() for name in ("system-auth", "system-local-login")):
        raise RuntimeError("Нужен системный PAM-сервис /etc/pam.d/shoji-lock для этой ОС.")
    directory = runtime / "pam"
    directory.mkdir(mode=0o700, exist_ok=True)
    # pam_start_confdir resolves includes in its own directory. Keep includes
    # linked to the installed system policy, including transitive includes.
    for source in policy.iterdir():
        target = directory / source.name
        if source.is_file() and source.name != "shoji-lock" and not target.is_symlink() and not target.exists():
            target.symlink_to(source)
    shutil.copyfile(SOURCE / "pam/shoji-lock", directory / "shoji-lock")
    (directory / "shoji-lock").chmod(0o600)
    return str(directory), "shoji-lock"


def background_url():
    fallback = (SOURCE.parent / "assets/default-wallpaper.svg").as_uri()
    try:
        document = json.loads((SOURCE.parent / "wallpapers.json").read_text())
        outputs = document.get("outputs", {})
        primary = os.environ.get("SHOJI_PRIMARY_OUTPUT", "")
        candidates = [outputs.get(primary), *outputs.values()]
        for value in candidates:
            if not isinstance(value, str):
                continue
            parsed = urlparse(value)
            if parsed.scheme not in ("", "file"):
                continue
            path = Path(unquote(parsed.path) if parsed.scheme == "file" else value)
            if path.is_absolute() and path.is_file():
                return path.as_uri()
    except (OSError, ValueError, AttributeError):
        pass
    return fallback


def check(environment):
    checked_env = dict(environment, WAYLAND_DEBUG="1")
    result = subprocess.run(
        ["quickshell", "--path", str(SOURCE.parent / "lock-check.qml"), "--no-color"],
        env=checked_env, capture_output=True, text=True, timeout=10,
    )
    output = result.stdout + result.stderr
    if result.returncode or "SHOJI_LOCK_CHECK_OK" not in output:
        # No authentication takes place here; diagnostics contain no password.
        errors = [line for line in output.splitlines() if "ERROR" in line or "WARN" in line]
        raise RuntimeError("Не загрузились компоненты блокировки. " + " ".join(errors[-4:]))
    if "ext_session_lock_manager_v1" not in output:
        raise RuntimeError("Текущий композитор не объявляет протокол блокировки Wayland.")


def status():
    try:
        result = subprocess.run(
            ["quickshell", "ipc", "--path", str(SOURCE.parent / "lock.qml"), "call", "session", "status"],
            capture_output=True, text=True, timeout=1,
        )
        if result.returncode == 0:
            return json.loads(result.stdout)
    except (ValueError, subprocess.TimeoutExpired):
        pass
    return None


def start(environment, runtime):
    # Serialise launchers, not the locker. The detached process survives a panel
    # reload; --no-duplicate also protects launches outside this helper.
    with (runtime / "launch.lock").open("a") as launch_lock:
        fcntl.flock(launch_lock, fcntl.LOCK_EX)
        existing = status()
        if existing and existing.get("secure"):
            return
        check(environment)
        log_path = runtime / "locker.log"
        descriptor = os.open(log_path, os.O_WRONLY | os.O_CREAT | os.O_APPEND | os.O_NOFOLLOW, 0o600)
        with os.fdopen(descriptor, "a") as log:
            process = subprocess.Popen(
                ["quickshell", "--no-duplicate", "--path", str(SOURCE.parent / "lock.qml"), "--no-color"],
                env=environment, stdin=subprocess.DEVNULL, stdout=log, stderr=log,
                start_new_session=True, close_fds=True,
            )
        deadline = time.monotonic() + 7
        while time.monotonic() < deadline:
            current = status()
            if current and current.get("secure"):
                return
            if process.poll() is not None:
                raise RuntimeError("Процесс блокировки завершился. См. " + str(log_path))
            time.sleep(0.1)
        # Never kill a possibly secure lock: a conformant compositor keeps a
        # failed client's session locked, which needs recovery from another TTY.
        raise RuntimeError("Нет подтверждения блокировки. См. " + str(log_path))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="Check QML, PAM policy and compositor; do not lock")
    mode.add_argument("--preview", action="store_true", help="Open a non-locking preview window")
    args = parser.parse_args()
    environment = dict(os.environ, SHOJI_LOCK_BACKGROUND=background_url())
    if args.preview:
        return subprocess.call(["quickshell", "--path", str(SOURCE.parent / "lock-preview.qml")], env=environment)
    runtime = private_runtime()
    directory, service = pam_configuration(runtime)
    environment.update(SHOJI_LOCK_PAM_DIRECTORY=directory, SHOJI_LOCK_PAM_SERVICE=service)
    if args.check:
        check(environment)
        print(f"OK: QML loads; ext-session-lock-v1 available; PAM policy {directory}/{service}.")
        print("Password authentication and actual locking were not attempted.")
        return 0
    start(environment, runtime)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
