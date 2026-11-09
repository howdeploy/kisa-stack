#!/usr/bin/env python3
"""Check installer preflight and local notification settings in a disposable home."""
from contextlib import redirect_stderr, redirect_stdout
import importlib.util
from io import StringIO
import json
import os
from pathlib import Path
import sys
import tempfile
from unittest.mock import patch

script = Path(__file__).with_name("install.py")
spec = importlib.util.spec_from_file_location("dotfiles_installer", script)
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)

with tempfile.TemporaryDirectory(prefix="shoji-install-check-") as directory:
    root = Path(directory)
    publication = root / "publication"
    source = publication / "config/shoji-shell"
    source.mkdir(parents=True)
    (source / "example.qml").write_text("// publication fixture\n")
    (source / "notification-policy.json").write_text("not publication material")
    home = root / "desktop user"
    local = home / ".config/shoji-shell"
    local.mkdir(parents=True)
    policy = {"version": 1, "quiet": True, "exceptions": ["example.desktop"]}
    (local / "notification-policy.json").write_text(json.dumps(policy))
    (local / "integrations.env").write_text("SHOJI_ENABLE_VOICE=0\n")
    args = [str(script), "--target-home", str(home), "--component", "shoji-shell", "--apply"]
    with patch.object(installer, "ROOT", publication), patch.object(sys, "argv", args), \
         patch.dict(os.environ, {"SHOJI_QUICKSHELL": ""}), patch.object(installer.os, "geteuid", return_value=1000), \
         patch.object(installer.shutil, "which", return_value="fixture"), \
         patch.object(installer.importlib.util, "find_spec", return_value=object()), \
         redirect_stdout(StringIO()), redirect_stderr(StringIO()):
        try:
            installer.main()
        except SystemExit as error:
            assert error.code == 2
        else:
            raise AssertionError("Missing patched shell passed preflight")
        assert json.loads((local / "notification-policy.json").read_text()) == policy
        assert not (home / ".local/state/kisa-dotfiles/backups").exists()
        binary = home / ".local/share/shoji-shell/quickshell/bin/quickshell"
        binary.parent.mkdir(parents=True)
        binary.write_text("fixture, never executed")
        binary.chmod(0o755)
        for _ in range(2):
            installer.main()
            assert json.loads((local / "notification-policy.json").read_text()) == policy
            assert (local / "integrations.env").read_text() == "SHOJI_ENABLE_VOICE=0\n"
            assert (local / "example.qml").is_file()
    assert len(list(home.glob(".local/state/kisa-dotfiles/backups/*/manifest.json"))) == 2
print("Patched-shell preflight, private-policy exclusion/preservation and repeat-install backups: OK")
