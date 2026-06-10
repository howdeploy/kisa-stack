#!/usr/bin/env bash
# UserPromptSubmit hook — напоминание про LLM Wiki как точку анализа каждый 3-й промпт.
# Подстраховка между компактами (после компакта эстафету держит wiki-anchor.sh с source=compact).
# Зависимость: jq.
input=$(cat 2>/dev/null)
sid=$(printf '%s' "$input" | jq -r '.session_id // "unknown"' 2>/dev/null || echo unknown)
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""'        2>/dev/null || echo "")

# Фильтр: молчать в автоворкерах и изолированных воркспейсах (вики там нерелевантна).
# Добавьте свои паттерны через | : *worktree*|*мой-воркспейс*|*-worker*
case "$cwd" in
  *worktree*) exit 0 ;;
esac

cnt_file="/tmp/cc-wiki-${sid}"
cnt=$(cat "$cnt_file" 2>/dev/null || echo 0)
cnt=$((cnt + 1))
echo "$cnt" > "$cnt_file"

if [ $((cnt % 3)) -eq 0 ]; then
  echo "Напоминание: стартовая точка анализа — LLM Wiki (claude-code/pages/components.md — маппинг инструментов). Сверься перед содержательным ответом; нужный инструмент бери по маппингу, не по догадке. Язык — русский."
fi
exit 0
