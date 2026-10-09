#!/usr/bin/env python3
"""Preview by default; copy selected desktop components with private backups."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import tempfile

ROOT = Path(__file__).resolve().parents[1]
COMPONENTS = ("shojiwm", "shoji-shell", "walker", "elephant", "ghostty", "portals", "icons", "bin")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="write files; default only prints the plan")
    parser.add_argument("--component", choices=COMPONENTS, action="append", help="repeat to select components; default: all")
    parser.add_argument("--target-home", type=Path, help="stage into an isolated home; ignore XDG directory overrides")
    args = parser.parse_args()
    home = args.target_home.resolve() if args.target_home else Path.home()
    config = home / ".config" if args.target_home else Path(os.environ.get("XDG_CONFIG_HOME") or home / ".config")
    data = home / ".local/share" if args.target_home else Path(os.environ.get("XDG_DATA_HOME") or home / ".local/share")
    state = home / ".local/state" if args.target_home else Path(os.environ.get("XDG_STATE_HOME") or home / ".local/state")
    for path in (home, config, data, state):
        if not path.is_absolute() or any(c in str(path) for c in '\n\r\0'):
            parser.error("Home and XDG paths must be absolute and contain no line breaks")
        if path == ROOT or ROOT.is_relative_to(path) and path != home:
            parser.error("XDG targets must not contain the source checkout")
    plan = []
    for name in dict.fromkeys(args.component or COMPONENTS):
        if name == "portals":
            plan.append((ROOT / "config/xdg-desktop-portal/shojiwm-portals.conf", config / "xdg-desktop-portal/shojiwm-portals.conf"))
        elif name == "icons":
            plan.append((ROOT / "data/icons/Shoji", data / "icons/Shoji"))
        elif name == "bin":
            plan.append((ROOT / "bin/codex-resume-ghostty", home / ".local/bin/codex-resume-ghostty"))
        else:
            plan.append((ROOT / "config" / name, config / name))
    for src, dst in plan:
        if dst == ROOT or dst.is_relative_to(ROOT) or ROOT.is_relative_to(dst):
            parser.error("Install targets must be outside the source checkout")
        print(f"{src.relative_to(ROOT)} -> {dst}" + (" (backup existing)" if dst.exists() or dst.is_symlink() else ""))
    if not args.apply:
        print("Preview only. Compile the QML shaders, then pass --apply to install. No services will be restarted.")
        return
    if os.geteuid() == 0:
        parser.error("Run as your desktop user, not root or sudo")
    # Validate prerequisites before moving any existing configuration.
    for src, _ in plan:
        if src.name == "shoji-shell":
            for shader in src.joinpath("shaders").glob("*.frag"):
                if not shader.with_suffix(shader.suffix + ".qsb").is_file():
                    parser.error("Missing QML shader binaries; run scripts/build-shaders.sh first")
        if src.name == "shojiwm" and not Path("/usr/lib/shojiwm/packages/shoji_wm").is_dir():
            parser.error("Install the pinned ShojiWM fork and runtime first")
    os.umask(0o077)
    backup_root = state / "tab-stack/backups"
    backup_root.mkdir(parents=True, exist_ok=True)
    backup = Path(tempfile.mkdtemp(prefix=datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ-"), dir=backup_root))
    manifest = []
    print(f"Backup and restore manifest: {backup}")
    for index, (src, dst) in enumerate(plan):
        previous = backup / str(index)
        exists = dst.exists() or dst.is_symlink()
        entry = {"target": str(dst), "backup": str(previous) if exists else None}
        manifest.append(entry)
        (backup / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        if exists:
            shutil.move(str(dst), previous)
        dst.parent.mkdir(parents=True, exist_ok=True)
        try:
            if src.is_dir():
                shutil.copytree(src, dst, ignore=shutil.ignore_patterns("__pycache__", "*.pyc", "integrations.env", "wallpapers.json", "node_modules"))
            else:
                shutil.copy2(src, dst)
            if dst == config / "shojiwm":
                dst.joinpath("node_modules").mkdir()
                dst.joinpath("node_modules/shoji_wm").symlink_to("/usr/lib/shojiwm/packages/shoji_wm", target_is_directory=True)
            if dst == config / "shoji-shell" and previous.is_dir():
                for name in ("integrations.env", "wallpapers.json"):
                    old = previous / name
                    if old.is_file() and not old.is_symlink():
                        shutil.copy2(old, dst / name)
            if dst == config / "ghostty":
                file = dst / "config"
                file.write_text(file.read_text().replace("@CONFIG_HOME@", str(config)))
            if dst == config / "elephant":
                file = dst / "files.toml"
                file.write_text('name_pretty = "Файлы и папки"\nsearch_dirs = [' + json.dumps(str(home), ensure_ascii=False) + ']\n')
        except Exception:
            print(f"Installation stopped. Original files, if any, are in {previous}. See manifest.json; no backup was deleted.")
            raise
    print("Installed. Log into ShojiWM when ready; current services and session were not restarted.")


if __name__ == "__main__":
    main()
