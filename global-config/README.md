# Глобальный конфиг — CLAUDE.md + AGENTS.md + хуки

Продуманная система поведения для двух рантаймов: глобальный `CLAUDE.md` для Claude Code и парный к нему глобальный `AGENTS.md` для Codex CLI (идентичность, приоритеты, согласование, антипаттерны — одна методология, адаптированная под особенности каждого агента) + два хука, которые держат LLM Wiki в фокусе анализа на протяжении всей сессии — включая восстановление после компакта.

## Что внутри

| Файл | Назначение |
|---|---|
| `CLAUDE.md` | Шаблон глобального `~/.claude/CLAUDE.md` — ядро системы (Claude Code) |
| `AGENTS.md` | Шаблон глобального `~/.codex/AGENTS.md` — та же методология для Codex CLI |
| `hooks/wiki-anchor.sh` | SessionStart-хук: инжектит якорь вики на старте сессии и после компакта |
| `hooks/wiki-reminder.sh` | UserPromptSubmit-хук: напоминание про вики каждый 3-й промпт |
| `settings.hooks.example.json` | Пример подключения хуков в `~/.claude/settings.json` |

## Установка

1. **CLAUDE.md.** Откройте `CLAUDE.md`, замените плейсхолдеры `<...>` под свой сетап (путь к vault, пути к репо). Блоки, помеченные комментариями как опциональные (LLM Wiki, ObsidianDataWeave, маппинг скиллов), уберите или адаптируйте, если не используете эти компоненты. Затем:

   ```bash
   cp CLAUDE.md ~/.claude/CLAUDE.md
   ```

2. **AGENTS.md (Codex).** Тот же порядок: замените плейсхолдеры `<...>`, удалите ненужные опциональные блоки (LLM Wiki, rtk-include в шапке). Затем:

   ```bash
   cp AGENTS.md ~/.codex/AGENTS.md
   ```

3. **Хуки.** Понадобится `jq` (`sudo pacman -S jq` / `sudo apt install jq`).

   ```bash
   mkdir -p ~/.claude/hooks
   cp hooks/wiki-anchor.sh hooks/wiki-reminder.sh ~/.claude/hooks/
   chmod +x ~/.claude/hooks/wiki-anchor.sh ~/.claude/hooks/wiki-reminder.sh
   ```

   В `wiki-anchor.sh` укажите путь к своему vault (переменная `WIKI_VAULT` в начале файла). В `wiki-reminder.sh` при желании дополните фильтр директорий, где напоминание не нужно.

4. **Подключение хуков.** Перенесите блок `hooks` (и `autoMemoryEnabled`, если ведете память в вики, а не в авто-памяти Claude Code) из `settings.hooks.example.json` в свой `~/.claude/settings.json`. После правки перезапустите Claude Code.

## Как это работает

- `CLAUDE.md` и `AGENTS.md` задают одинаковое поведение в обоих рантаймах: сначала думать, потом делать; решать ровно поставленную задачу; проверять факты инструментами, а не памятью; согласовывать изменения до их внесения.
- `wiki-anchor.sh` решает главную боль длинных сессий: compaction вытесняет директивы из контекста. Хук срабатывает на `startup|resume|compact` и реинжектит якорь заново.
- `wiki-reminder.sh` подстраховывает между компактами: каждый 3-й промпт коротко напоминает модели стартовую точку анализа.
