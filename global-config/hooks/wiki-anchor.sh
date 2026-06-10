#!/usr/bin/env bash
# SessionStart hook — якорь LLM Wiki как стартовой точки анализа.
# Реинжектит жёсткие директивы на старте сессии И после компакта (source=compact),
# потому что compaction вытесняет системные директивы из контекста.
#
# Настройка: укажите путь к своему vault (или задайте переменную окружения WIKI_VAULT).
# Зависимость: jq.
WIKI_VAULT="${WIKI_VAULT:-$HOME/LLM Wiki}"

input=$(cat 2>/dev/null)
source=$(printf '%s' "$input" | jq -r '.source // "startup"' 2>/dev/null || echo startup)

if [ "$source" = "compact" ]; then
  echo "[reinject after compaction] Контекст был сжат — восстанавливаю жёсткие директивы:"
fi

cat <<EOF
## LLM Wiki — обязательная стартовая точка анализа (MUST)
- Vault: $WIKI_VAULT/
- Методология claude-code: pages/overview.md и pages/components.md — читать ДО решения задач по инструментам/пайплайнам/маппингу.
- Перед содержательным ответом сверься с вики. Нет нужной страницы в контексте — прочитай Read, ПОТОМ решай.
- Язык ответов: всегда русский.
EOF
