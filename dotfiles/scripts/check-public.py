#!/usr/bin/env python3
"""Scan the publication tree; report locations/categories, never matched values."""
import argparse
from pathlib import Path
import re
import subprocess
import sys

REPO = Path(__file__).resolve().parents[2]
SCOPES = ("dotfiles", "skills/shojiwm", "skills/shoji-shaders")
RULES = {
    "credential format": re.compile(r"(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{30,}|sk-[A-Za-z0-9_-]{24,}|AKIA[0-9A-Z]{16}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----)"),
    "credential literal": re.compile(r'''(?i)(?:api[_-]?key|access[_-]?token|password|client[_-]?secret)\s*[=:]\s*["']([A-Za-z0-9_+/=.-]{20,})["']'''),
    "credential in URL": re.compile(r"https?://[^\s/@:]+:[^\s/@]+@"),
    "private host": re.compile(r"\b(?:192\.168\.\d{1,3}\.\d{1,3}|10\.\d{1,3}\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})\b"),
    "personal absolute path": re.compile(r"/(?:home|Users)/[A-Za-z0-9_.-]+|/mnt/[A-Za-z0-9_.-]+"),
}
DISALLOWED = re.compile(r"(?:^|/)(?:auth\.json|hosts\.yml|integrations\.env|wallpapers\.json|\.env(?:\.[^/]+)?|.*\.(?:sqlite3?|db|log|pem|key|qsb|pyc)|.*(?:\.bak|\.backup).*)(?:$|/)")
BINARY = {"dotfiles/config/shoji-shell/assets/panel-grain.png", "dotfiles/config/walker/themes/shoji/grain.png"}
# Reviewed generated sprite sheets used by HomeMascots.js; no screenshots.
BINARY.update(f"dotfiles/config/shoji-shell/assets/home-clock-v2/{digit}.png" for digit in range(10))
BINARY.update(f"dotfiles/config/shoji-shell/assets/home-clock-v3/{digit}.png" for digit in (0, 2, 4, 9))
BINARY.update(f"dotfiles/config/shoji-shell/assets/home-clock-v4/{digit}.png" for digit in (3, 6, 7, 8))
BINARY.update(f"dotfiles/config/shoji-shell/assets/home-clock-v5/{variant}{digit}.png"
              for variant in "bcd" for digit in range(10))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--staged", action="store_true", help="inspect index blobs rather than working files")
    args = parser.parse_args()
    flags = ["--cached"] if args.staged else ["--cached", "--others", "--exclude-standard"]
    result = subprocess.check_output(["git", "ls-files", "-z", *flags, "--", *SCOPES], cwd=REPO)
    failures = []
    paths = sorted(set(p.decode() for p in result.split(b"\0") if p))
    for name in paths:
        if DISALLOWED.search(name) and not name.endswith(".env.example"):
            failures.append((name, 0, "runtime/credential filename"))
        file = REPO / name
        if args.staged:
            mode = subprocess.check_output(["git", "ls-files", "-s", "--", name], cwd=REPO).split()[0]
            if mode == b"120000":
                failures.append((name, 0, "symlink"))
            raw = subprocess.check_output(["git", "show", f":{name}"], cwd=REPO)
        else:
            if file.is_symlink():
                failures.append((name, 0, "symlink"))
                continue
            raw = file.read_bytes()
        if name in BINARY:
            if not raw.startswith(b"\x89PNG\r\n\x1a\n"):
                failures.append((name, 0, "unexpected binary format"))
            continue
        try:
            contents = raw.decode("utf-8")
        except UnicodeDecodeError:
            failures.append((name, 0, "unreviewed binary"))
            continue
        for line_number, line in enumerate(contents.splitlines(), 1):
            for category, pattern in RULES.items():
                if pattern.search(line):
                    failures.append((name, line_number, category))
    for name, line, category in failures:
        print(f"{name}:{line}: {category}")
    print(f"Scanned {len(paths)} publication files; {len(failures)} findings. Manual review is still required.")
    return bool(failures) or not paths


if __name__ == "__main__":
    sys.exit(main())
