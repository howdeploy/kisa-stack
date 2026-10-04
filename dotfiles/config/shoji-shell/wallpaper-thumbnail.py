#!/usr/bin/env python3
"""Build one cached preview; stdout is one JSON reply for Quickshell."""
import hashlib
import json
import os
from pathlib import Path
import sys
import subprocess
import tempfile
from urllib.parse import unquote, urlsplit


def thumbnail(url, cache_root):
    parsed = urlsplit(url)
    if parsed.scheme != "file" or parsed.netloc not in ("", "localhost"):
        raise ValueError("Expected a local file URL")
    source = Path(unquote(parsed.path)).resolve(strict=True)
    info = source.stat()
    if not source.is_file():
        raise ValueError("Expected an image file")
    stamp = f"v2:{source}:{info.st_mtime_ns}:{info.st_ctime_ns}:{info.st_size}"
    target = cache_root / (hashlib.sha256(stamp.encode()).hexdigest() + ".png")
    if target.is_file():
        return target.as_uri()

    # Pillow is only imported on cache misses; warm navigation needs no decoder.
    from PIL import Image, ImageOps

    cache_root.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        video = source.suffix.lower() in ('.mp4', '.webm', '.mkv', '.mov', '.avi', '.m4v', '.wmv')
        if video:
            with tempfile.NamedTemporaryFile(dir=cache_root, suffix='.png', delete=False) as handle:
                temporary = Path(handle.name)
            subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-y', '-i', str(source),
                '-frames:v', '1', '-vf', 'scale=900:600:force_original_aspect_ratio=decrease',
                '-threads', '1', str(temporary)], check=True, capture_output=True, timeout=15)
        else:
            with Image.open(source) as image:
                image.thumbnail((900, 600), Image.Resampling.LANCZOS)
                preview = ImageOps.exif_transpose(image).convert("RGBA")
                with tempfile.NamedTemporaryFile(dir=cache_root, suffix=".png", delete=False) as handle:
                    temporary = Path(handle.name)
                    preview.save(handle, format="PNG")
        after = source.stat()
        if (after.st_mtime_ns, after.st_ctime_ns, after.st_size) != (info.st_mtime_ns, info.st_ctime_ns, info.st_size):
            raise OSError("Image changed during decoding; reopen the picker to retry")
        os.replace(temporary, target)
        temporary = None
        return target.as_uri()
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main():
    url = sys.argv[1]
    cache = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    if not cache.is_absolute():
        cache = Path.home() / ".cache"
    try:
        result = {"url": url, "thumbnail": thumbnail(url, cache / "shoji-shell" / "thumbnails")}
    except (OSError, ValueError, ImportError, subprocess.SubprocessError) as error:
        result = {"url": url, "thumbnail": "", "error": str(error)}
    print(json.dumps(result, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
