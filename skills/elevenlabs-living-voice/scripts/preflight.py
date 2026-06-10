#!/usr/bin/env python3
"""Preflight text shaping for Hermes TTS.

Reads raw text from stdin and emits a more speech-friendly version for
ElevenLabs. Conservative by design: preserve semantics, just normalize pacing,
spacing, and model-specific pause handling.
"""

from __future__ import annotations

import os
import re
import sys

_BREAK_RE = re.compile(r"<break\s+time=[\"']?([0-9.]+)s?[\"']?\s*/?>", re.IGNORECASE)
_MULTI_SPACE_RE = re.compile(r"[ \t]{2,}")
_MULTI_NL_RE = re.compile(r"\n{3,}")
_ELLIPSIS_RE = re.compile(r"(?:\s*\.\s*){3,}")
_DASH_RE = re.compile(r"\s*[—–-]\s*")
_COMMA_RE = re.compile(r"\s*,\s*")
_SENTENCE_GAP_RE = re.compile(r"([.!?])\s+(?=[^\s])")


def _pause_replacement_v3(seconds: float) -> str:
    if seconds <= 0.35:
        return ", "
    if seconds <= 0.9:
        return " ... "
    return ". ... "


def _normalize_common(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = _MULTI_SPACE_RE.sub(" ", text)
    text = _MULTI_NL_RE.sub("\n\n", text)
    text = _COMMA_RE.sub(", ", text)
    text = _DASH_RE.sub(" — ", text)
    text = _ELLIPSIS_RE.sub("...", text)
    text = _SENTENCE_GAP_RE.sub(r"\1\n", text)
    text = re.sub(r"\n +", "\n", text)
    text = re.sub(r" +\n", "\n", text)
    return text.strip()


def _for_v3(text: str) -> str:
    def repl(match: re.Match[str]) -> str:
        try:
            seconds = float(match.group(1))
        except Exception:
            seconds = 0.6
        return _pause_replacement_v3(seconds)

    text = _BREAK_RE.sub(repl, text)
    text = re.sub(r"\n{2,}", "\n", text)
    text = re.sub(r"(?m)^\s*([-*])\s+", "", text)
    return _normalize_common(text)


def _for_v2(text: str) -> str:
    # v2 can keep explicit SSML breaks, so we only normalize surrounding text.
    text = re.sub(r"\s*(<break\s+time=[^>]+/?>)\s*", r" \1 ", text, flags=re.IGNORECASE)
    return _normalize_common(text)


def main() -> int:
    text = sys.stdin.read()
    if not text.strip():
        return 0

    provider = (os.getenv("HERMES_TTS_PROVIDER") or "").strip().lower()
    model_id = (os.getenv("HERMES_TTS_MODEL_ID") or "").strip().lower()

    if provider == "elevenlabs" and model_id.startswith("eleven_v3"):
        out = _for_v3(text)
    elif provider == "elevenlabs" and "multilingual_v2" in model_id:
        out = _for_v2(text)
    else:
        out = _normalize_common(text)

    sys.stdout.write(out.strip())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
