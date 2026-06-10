#!/usr/bin/env bash
set -euo pipefail

# Установка скиллов в Claude Code (~/.claude/skills), Codex (~/.codex/skills)
# и/или Hermes (~/.hermes/skills). Скиллы взаимно совместимы: один и тот же
# SKILL.md работает во всех трех рантаймах.
#
# Использование:
#   ./install.sh <skill-name|all> [--claude] [--codex] [--hermes]
#
# Без флагов рантайма ставит в Claude Code + Codex (--hermes только явно).
# Существующий скилл бэкапится с таймстампом. Если твой Hermes раскладывает
# скиллы по категориям (media/, note-taking/, ...), перенеси папку скилла в
# нужную категорию после установки или задай HERMES_HOME.

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
skills_dir="$repo_dir/skills"

usage() {
  echo "Usage: $0 <skill-name|all> [--claude] [--codex] [--hermes]" >&2
  echo "Available skills:" >&2
  for d in "$skills_dir"/*/; do
    [ -d "$d" ] || continue
    echo "  - $(basename "$d")" >&2
  done
}

if [ $# -lt 1 ]; then
  usage
  exit 2
fi

selection="$1"
shift

want_claude=0
want_codex=0
want_hermes=0
for arg in "$@"; do
  case "$arg" in
    --claude) want_claude=1 ;;
    --codex)  want_codex=1 ;;
    --hermes) want_hermes=1 ;;
    *) usage; exit 2 ;;
  esac
done
if [ "$want_claude" -eq 0 ] && [ "$want_codex" -eq 0 ] && [ "$want_hermes" -eq 0 ]; then
  want_claude=1
  want_codex=1
fi

targets=()
[ "$want_claude" -eq 1 ] && targets+=("$HOME/.claude/skills")
[ "$want_codex" -eq 1 ] && targets+=("${CODEX_HOME:-$HOME/.codex}/skills")
[ "$want_hermes" -eq 1 ] && targets+=("${HERMES_HOME:-$HOME/.hermes}/skills")

install_one() {
  local name="$1" target_root="$2"
  local source_dir="$skills_dir/$name"
  local target_dir="$target_root/$name"

  if [ ! -f "$source_dir/SKILL.md" ]; then
    echo "Skill not found: $name" >&2
    exit 1
  fi

  mkdir -p "$target_root"

  if [ -e "$target_dir" ]; then
    local backup_dir="${target_dir}.backup-$(date +%Y%m%d-%H%M%S)"
    mv "$target_dir" "$backup_dir"
    echo "Backed up existing skill to: $backup_dir"
  fi

  cp -a "$source_dir" "$target_dir"

  if [ -d "$target_dir/scripts" ]; then
    find "$target_dir/scripts" -type f \( -name '*.sh' -o -name '*.py' -o -name '*.js' \) -exec chmod +x {} +
  fi

  echo "Installed $name -> $target_dir"
}

if [ "$selection" = "all" ]; then
  names=()
  for d in "$skills_dir"/*/; do
    [ -d "$d" ] || continue
    names+=("$(basename "$d")")
  done
else
  names=("$selection")
fi

for target_root in "${targets[@]}"; do
  for name in "${names[@]}"; do
    install_one "$name" "$target_root"
  done
done

echo ""
echo "Done. Перезапустите Claude Code / Codex / Hermes, чтобы список скиллов обновился."
