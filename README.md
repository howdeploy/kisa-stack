# KISA Stack [![Awesome](https://awesome.re/badge.svg)](https://awesome.re)

Личный сетап для вайбкодинга: продуманная система поведения AI-ассистентов, скиллы, хуки и плагины. Все, что я реально гоняю каждый день — в виде, который можно развернуть у себя за пять минут.

Каждый артефакт совместим сразу с тремя рантаймами: **Claude Code**, **Codex CLI** и **Hermes**.

## Contents

- [Глобальный конфиг](#глобальный-конфиг)
- [Скиллы](#скиллы)
- [Плагины](#плагины)
- [Установка](#установка)
- [Совместимость](#совместимость)

## Глобальный конфиг

Ядро системы — поведение ассистента: сначала думать, потом делать; решать ровно поставленную задачу; проверять факты инструментами, а не памятью; согласовывать изменения до их внесения.

- [CLAUDE.md](global-config/CLAUDE.md) — глобальный конфиг Claude Code: идентичность, приоритеты, правила, антипаттерны.
- [AGENTS.md](global-config/AGENTS.md) — та же методология, адаптированная под Codex CLI.
- [Хуки](global-config/hooks) — якорь LLM Wiki на старте сессии и после компакта + периодическое напоминание: директивы переживают сжатие контекста.

Пошаговая установка: [global-config/README.md](global-config/README.md).

## Скиллы

Один и тот же скилл ставится в `~/.claude/skills/`, `~/.codex/skills/` или `~/.hermes/skills/` — формат общий, Codex-метаданные и Hermes-конвенции уже внутри.

### Ресерч и знания

- [researcher](skills/researcher) - Signal-only ресерч в двух режимах (quick-scan / deep-research) с фолбэками и отработанными спецслучаями: от X-тредов про взломы до локальных коммунальных аварий.
- [gamer-signal](skills/gamer-signal) - Игровой ресерч строго по доверенным источникам (официальные патчноуты, Steam, allowlist-вики). Никаких выдуманных механик: нет подтверждения — честное «не нашла».
- [telegram-chat-wiki](skills/telegram-chat-wiki) - Превращает экспорт Telegram-переписки в двухслойную wiki-память: сырые day-chunks по датам + hub-страница собеседника. Потом можно спрашивать «что я обсуждал с Колей?».

### Контент и медиа

- [css-graphics](skills/css-graphics) - Графика средствами HTML/CSS/SVG с рендером в PNG/JPG через Puppeteer: обложки, OG-картинки, бейджи и баннеры без дизайнера.
- [stream-timecodes](skills/stream-timecodes) - Ровно 18 таймкодов для стрима или подкаста из VTT-транскрипции, равномерно по длительности и без воды.
- [voice-summary](skills/voice-summary) - Выжимки из голосовых: структурный пересказ в 4 блока или action-first режим — войс сразу превращается в ТЗ, prompt или баг-лист.

### Музыка и озвучка

- [elevenlabs-living-voice](skills/elevenlabs-living-voice) - Живая речь в ElevenLabs: нарезка текста на дыхательные блоки, паузы и audio tags под v2/v3, плюс feedback loop через voice settings API.
- [suno-music](skills/suno-music) - Генерация треков через EvoLink Suno API со специализацией на voiceover-safe фонах: банк промптов для underscore, seamless loop и muted synthwave.
- [ai-music-and-audio-tools](skills/ai-music-and-audio-tools) - Зонтик по AI-музыке: лирика и структура песен, промптинг Suno-подобных систем, локальная генерация (AudioCraft/MusicGen), спектрограммы.

### Система и железо

- [wine-hid-device-tools](skills/wine-hid-device-tools) - Запуск Windows-утилит для HID-клавиатур под Wine/PortProton/Bottles: диагностика hidraw, udev-правила, winebus-реестр — вместо «ставь виртуалку».

### Личное

- [emotional-support](skills/emotional-support) - Режим эмоциональной поддержки: активное слушание, валидация и аккуратный CBT-рефрейминг вместо дежурного «все будет хорошо».

## Плагины

Мой набор плагинов Claude Code со ссылками, описаниями и шпаргалкой по установке — в [plugins.md](plugins.md). Там же — наборы и тулзы вне маркетплейса (gstack, gsd-core, rtk, мой пайплайн [ObsidianDataWeave](https://github.com/howdeploy/ObsidianDataWeave)), «фразы кабанчика» и мой [MTGA](https://github.com/howdeploy/MTGA) (Claude отвечает как трамповские твиты, TREMENDOUS!).

## Установка

Скиллы ставятся одной командой из корня репозитория:

```bash
# все скиллы в Claude Code + Codex
./install.sh all

# один скилл в конкретный рантайм
./install.sh researcher --claude
./install.sh suno-music --codex
./install.sh voice-summary --hermes
```

Существующие скиллы бэкапятся с таймстампом. Глобальный конфиг и хуки — по инструкции в [global-config/README.md](global-config/README.md).

Для suno-music дополнительно нужен API-ключ EvoLink: скопируй `.env.example` в `.env` рядом со скриптами скилла.

## Совместимость

| Рантайм | Скиллы | Конфиг | Примечания |
|---|---|---|---|
| Claude Code | `~/.claude/skills/` | `~/.claude/CLAUDE.md` + хуки | основной сетап |
| Codex CLI | `~/.codex/skills/` | `~/.codex/AGENTS.md` | у каждого скилла есть `agents/openai.yaml` |
| Hermes | `~/.hermes/skills/` | — | `metadata.hermes` во frontmatter; маппинг инструментов описан в самих скиллах |

Скиллы, рожденные в одной среде, несут примечания для двух других: имена инструментов (`Bash` ↔ `terminal`, `Tavily` ↔ `web_search`) и конвенции доставки (`MEDIA:/path`, Telegram) — логика от рантайма не зависит.

## Contributing

Это подборка моего личного сетапа для моей аудитории. Нашли проблему или хотите предложить улучшение — открывайте issue.
