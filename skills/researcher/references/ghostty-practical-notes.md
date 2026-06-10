# Ghostty practical notes

Короткий конденсат по Ghostty для задач формата «посмотри настройки и скажи, нужно ли мне это». Не нормативный reference, а practical layer поверх официальных docs.

## Как объяснять Ghostty-опции

Для user-facing разбора каждой опции прогоняй 4 вопроса:
1. Что это делает простыми словами.
2. Что меняется в ежедневной работе.
3. Какой главный минус/компромисс.
4. Вердикт: скорее да / спорно / игрушка.

Особенно полезно, когда пользователь уже прислал свой config и хочет понять не «что еще можно поставить», а «что реально улучшит опыт».

## Проверенные нюансы из docs

### Scrollback vs auto-scroll
- `scrollback-limit` — это размер scrollback buffer **в байтах**, а не число строк.
- Когда лимит достигнут, Ghostty выкидывает самые старые строки.
- Это **не** настройка автоскролла.
- За автоскроллоподобное поведение отвечает `scroll-to-bottom`.
- У `scroll-to-bottom` есть как минимум опции `keystroke` и `output`.
- Практическая формулировка: scrollback = «сколько прошлого помню», scroll-to-bottom = «когда тянуть вид вниз к новому выводу».

### Shell integration и SSH
- Shell integration не «улучшает TUI-агента изнутри» и не добавляет ему отдельный UI.
- Она улучшает терминальную среду вокруг него: prompt-aware behavior, cwd inheritance, prompt navigation/selection, cursor behavior.
- Для `ssh` есть отдельные optional wrappers:
  - передача Ghostty terminfo; или
  - fallback к `TERM=xterm-256color` ради совместимости.
- Это особенно полезно в сценарии `local Ghostty -> ssh -> remote shell -> launch agent`, где важнее стабильность и меньше terminal-quirks, а не новые визуальные функции внутри Claude Code / Codex.

### Copy on select
- `copy-on-select = clipboard` — мгновенное копирование выделенного текста в системный буфер.
- Обычно хорошо заходит тем, кто часто копирует команды, пути, логи.
- Может раздражать тех, кто часто выделяет текст просто чтобы посмотреть, а не копировать.

### Quick terminal
- Это quake-style dropdown terminal по хоткею.
- Полезен для быстрых одноразовых команд, логов, `git status`, коротких ssh-сессий.
- Не обязательно заменяет основной терминал; часто лучше как быстрый карманный shell.

### Shaders
- Большинство shader-эффектов хороши как mood preset, но не как daily driver.
- Для постоянной работы чаще выживают только очень мягкие эффекты вроде subtle bloom / glow.
- Жесткие CRT, Pip-Boy, scanlines, chromatic aberration чаще ухудшают читаемость long-form терминальной работы.

## Пользовательский pain point: названия вкладок и сплитов
- У людей с несколькими одинаковыми project-folder names часто возникает проблема одинаковых tab titles.
- Community signal: в Ghostty есть UI-команда `Change Tab Title` через command palette для ручного custom naming.
- Для exact keybind-level answer перепроверь keybind action reference: полезные действия — `prompt_tab_title` и `prompt_surface_title`.
- Важно не перепутать: наличие surface title не означает, что Ghostty рисует постоянную видимую плашку/label на divider каждого split.
- Если пользователь спрашивает именно про always-visible split header, отвечай честно: manual naming есть, но отдельный постоянный UI-label для split boundary нужно подтверждать отдельно и не выдавать из воздуха.
- Если нужен exact declarative config path для persistent automation, перепроверь отдельно по актуальным docs/issues — не выдумывай ключ, если официальный reference его не показывает явно.

## Community shader sources worth checking
- Krone Corylus — Ghostty Shader Playground
- 12jihan — ghostty_shaders
- Alex Sherwin — my-ghostty-shaders
- erniee — gshaders
- luiscarlospando — CRT shader with chromatic aberration, glow, scanlines, dot matrix
- hackr-sh — ghostty-shaders

## Shader showcases worth preferring over repo lists
Когда пользователь хочет выбрать глазами, а не читать список репозиториев, приоритезируй showcase-источники:
- https://catskull.net/fun-with-ghostty-shaders.html — практический обзор со скринами/сочетаниями и ссылками на шейдеры
- https://jeffhottinger.com/blog/2025/02/how-to-configure-ghostty-as-a-retro-crt-on-mac — пример CRT-oriented setup с визуальным итогом
- https://www.youtube.com/watch?v=yJDn__NhOqI — showcase Ghostty shaders + setup context
- https://www.youtube.com/watch?v=FbeP45TQlE8 — GNOME/theme/shader supplementary showcase

## Sources to prefer
- Official:
  - https://ghostty.org/docs/config/reference
  - https://ghostty.org/docs/features
  - https://ghostty.org/docs/features/shell-integration
- Community / inspiration:
  - https://github.com/wyattgill9/Awesome-Ghostty
  - specific shader repos above
