# Плагины

Мой набор плагинов Claude Code: что стоит, откуда ставить и зачем.

Установка: сначала добавь маркетплейс, потом плагин из него:

```
/plugin marketplace add <github-repo>
/plugin install <имя>@<маркетплейс>
```

## Активные

- [tavily-tools](https://github.com/fcakyon/claude-codex-settings) — Веб-поиск и извлечение контента через Tavily MCP, с хуками и скиллами для правильного выбора инструмента. Ядро моего дип-ресерча. *(маркетплейс `claude-settings`)*
- [statusline-tools](https://github.com/fcakyon/claude-codex-settings) — Кроссплатформенный статуслайн: контекст сессии, стоимость, общий 5-часовой лимит аккаунта и время до сброса. *(маркетплейс `claude-settings`)*
- [codex](https://github.com/openai/codex-plugin-cc) — Официальный плагин OpenAI: гонять Codex прямо из Claude Code — code review и делегирование задач. Мой канал second opinion. *(маркетплейс `openai-codex`)*
- [python-development](https://github.com/wshobson/agents) — Python-стек: скиллы и агенты под современный тулинг (uv, ruff, pydantic, FastAPI, Django). *(маркетплейс `claude-code-workflows`)*
- [security-scanning](https://github.com/wshobson/agents) — SAST-анализ, сканирование зависимостей, OWASP Top 10, контейнерная безопасность, threat modeling. *(маркетплейс `claude-code-workflows`)*
- [blockchain-web3](https://github.com/wshobson/agents) — Web3-разработка: смарт-контракты, DeFi, NFT, тестирование. *(маркетплейс `claude-code-workflows`)*
- [claude-typing-ambient](https://github.com/howdeploy/Claude-typing-ambient) — Эмбиент-звук печатающей механической клавиатуры, пока Claude работает. Мой собственный плагин. *(маркетплейс `howdeploy-plugins`)*
- [MTGA](https://github.com/howdeploy/MTGA) — Make Terminal Great Again: Claude отвечает в стиле трамповских твитов (CAPS, самовосхваление, TREMENDOUS!), плюс 100 спин-фраз RU/EN и опциональные трамп-коммиты. Код, файлы и честность не трогает — только текст в чате. Тумблеры `/mtga:on|off|status`, прежние настройки бэкапятся. Мой собственный плагин. *(маркетплейс `mtga`)*
- [rust-analyzer-lsp](https://github.com/anthropics/claude-plugins-official) — LSP-интеграция rust-analyzer для работы с Rust. *(официальный маркетплейс Anthropic)*
- [pyright-lsp](https://github.com/anthropics/claude-plugins-official) — LSP-интеграция Pyright для Python. *(официальный маркетплейс Anthropic)*

## Установлены, но выключены

- [ccproxy-tools](https://github.com/fcakyon/claude-codex-settings) — Claude Code поверх кредитов GitHub Copilot, Gemini API, локальных ollama-моделей или любого LLM. *(маркетплейс `claude-settings`)*
- [claudecode-sounds](https://github.com/newink/codingagents) — Звуковые уведомления, когда Claude Code ждет твоего внимания. *(маркетплейс `codingagents`)*

## Наборы и тулзы вне маркетплейса

Ставятся не через `/plugin install`, а своими установщиками.

- [gstack](https://github.com/garrytan/gstack) — Сетап Garry Tan для Claude Code: большой набор скиллов — code review и QA с реальным браузером, design-пайплайны, plan-ревью (CEO / eng / design / DX), second opinion от Codex, ship/deploy-воркфлоу. Ставится одной вставкой в Claude Code (нужен Bun). Основа моего скиллового стека.
- [gsd-core](https://github.com/open-gsd/gsd-core) — Git. Ship. Done: spec-driven фреймворк фазовой разработки с context engineering — тяжелый ресерч, планирование и исполнение уходят в fresh-context сабагентов, основная сессия остается чистой. Мульти-рантайм (Claude Code, Codex, Gemini CLI, Cursor и др.), установка: `npx @opengsd/gsd-core@latest`. *(Переименованный Redux — форк комьюнити после скандала с автором оригинального GSD.)* У меня живет в Codex (`gsd-*` команды).
- [rtk](https://github.com/rtk-ai/rtk) — RTK (Rust Token Killer): CLI-прокси, который фильтрует и сжимает вывод команд до попадания в контекст LLM — экономия 60–90% токенов. Один Rust-бинарь, 100+ поддержанных команд, <10 мс оверхеда. Интеграции: Claude Code (PreToolUse-хук, `rtk init -g`), Codex (`rtk init -g --codex` → AGENTS.md + RTK.md — у меня подключен именно так), Cursor, Gemini CLI и др.

- [ObsidianDataWeave](https://github.com/howdeploy/ObsidianDataWeave) — Мой пайплайн обработки заметок Obsidian: enrich/atomize по Zettelkasten, импорт .docx и ведение LLM Wiki (`wiki_init` / `wiki_ingest` / `wiki_compile` / `wiki_lint`; единственный writer — `vault_writer.py`). Тот самый контур долговременной памяти, который якорят хуки из [global-config](global-config) — вики как source of truth, а не авто-заметки. В комплекте — скилл-адаптер для Claude Code.

## Фразы кабанчика

- [claude-code-spinner](https://github.com/i1kazantsev/claude-code-spinner) — «Замена фраз спиннера клод-кода для уважаемых вайбкодеров»: вместо `Thinking...` / `Pondering...` крутится «Обкашляю вопросик», «По красоте все сделаем» и еще 90+ фраз. Технически это не плагин, а пак `spinnerVerbs`, который вливается в `~/.claude/settings.json` (командой `/install-spinner` из репо или руками). Бонусом — Stop-хук «Вопросик на тормозах» со звуком.

> ⚠️ Автор предупреждает: единственный официальный источник — `github.com/i1kazantsev/claude-code-spinner`, существуют вредоносные копии проекта.
