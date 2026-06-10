---
name: css-graphics
description: Генерация CSS/SVG графики с рендером в PNG/JPG через Puppeteer. Use when пользователь просит "сделай графику", "нарисуй картинку", "создай изображение", "сгенерируй png", "css graphics", "css art", "svg graphic", "render to png", или даёт референсное изображение для воссоздания в CSS/SVG.
metadata:
  hermes:
    tags: [graphics, css, svg, png, render, puppeteer]
---

# CSS Graphics — генерация графики средствами HTML/CSS/SVG

> **Hermes:** команды запускай через `terminal`, временный HTML пиши файловым инструментом среды, готовый PNG/JPG отдавай в чат через `MEDIA:/absolute/path`.

Standalone скилл для создания графики. Пользователь описывает картинку текстом или даёт референсное изображение — ты пишешь HTML/CSS/SVG и рендеришь в PNG/JPG через Puppeteer.

Все пути в этом скилле — относительно базовой директории скилла (она сообщается при загрузке скилла; в Claude Code это `~/.claude/skills/css-graphics/`, в Codex — `~/.codex/skills/css-graphics/`).

## Первый запуск

Если Puppeteer ещё не установлен, выполни из базовой директории скилла:

```bash
bash scripts/setup.sh
```

## Режимы работы

### Режим 1 — из текстового описания

Пользователь описывает что хочет увидеть → ты пишешь HTML/CSS/SVG → рендеришь.

### Режим 2 — по референсному изображению

Пользователь даёт изображение → ты читаешь его через Read tool → анализируешь цвета, формы, layout, типографику → воссоздаёшь в CSS/SVG → рендеришь.

## Процесс рендера

1. **Write** HTML-файл в `.css-graphics-temp.html` (в CWD пользователя)
2. **Bash** — запустить render.js (путь к скрипту — от базовой директории скилла):
   ```bash
   node <база скилла>/scripts/render.js \
     --input .css-graphics-temp.html \
     --output <имя-файла>.png \
     --width <W> --height <H>
   ```
3. **Bash** — удалить временный файл: `rm .css-graphics-temp.html`
4. Сообщить пользователю путь к файлу и итоговые размеры

## Обязательная HTML-структура

Каждый сгенерированный HTML **обязан** содержать:

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      width: 100vw;
      height: 100vh;
      overflow: hidden;
    }
  </style>
  <!-- Google Fonts если нужны -->
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;900&display=swap" rel="stylesheet">
</head>
<body>
  <!-- Контент здесь -->
</body>
</html>
```

- `body` занимает весь viewport — размеры задаются через `--width`/`--height` в render.js
- `overflow: hidden` — ничего не выходит за границы
- Google Fonts подключать через `<link>` с fallback на `system-ui, sans-serif`

## CSS-техники для графики

- **Градиенты**: `linear-gradient`, `radial-gradient`, `conic-gradient`, множественные `background`
- **Формы**: `border-radius`, `clip-path` (polygon, circle, ellipse, path)
- **Глубина**: стекинг `box-shadow`, `drop-shadow`, `backdrop-filter: blur()`
- **Текстуры**: `repeating-linear-gradient`, SVG `<pattern>`, `feTurbulence`
- **Анимации не нужны** — рендерится статический скриншот

## SVG-техники

- `<defs>` + `<linearGradient>` / `<radialGradient>` для заливок
- `<path>` с командами M, L, C, Q, A для произвольных форм
- `<marker>` для стрелок на линиях
- `<text>` с `dominant-baseline` и `text-anchor` для точного позиционирования
- `<filter>` — `feGaussianBlur`, `feTurbulence`, `feDisplacementMap` для эффектов
- `<clipPath>` и `<mask>` для вырезания

## Стандартные размеры

| Название | width | height | Использование |
|----------|-------|--------|---------------|
| Full HD | 1920 | 1080 | Стандарт, презентации, обои |
| 4K | 3840 | 2160 | Высокое качество |
| Instagram Post | 1080 | 1080 | Квадрат для ленты |
| Instagram Story | 1080 | 1920 | Вертикальный формат |
| Twitter Card | 1200 | 675 | Превью ссылок |
| YouTube Thumbnail | 1280 | 720 | Обложки видео |
| Badge | 200 | 40 | Бейджи для README |
| Banner | 1200 | 300 | Шапки профилей |
| OG Image | 1200 | 630 | Open Graph для соцсетей |

## Параметры render.js

| Параметр | Дефолт | Описание |
|----------|--------|----------|
| `--input` | (обязательный) | Путь к HTML-файлу |
| `--output` | (обязательный) | Путь к выходному файлу (.png / .jpg / .jpeg) |
| `--width` | 1920 | Ширина viewport в пикселях |
| `--height` | 1080 | Высота viewport в пикселях |
| `--scale` | 2 | Device scale factor (2 = Retina, итого 3840x2160 для 1920x1080) |
| `--transparent` | false | Прозрачный фон (только PNG) |
| `--quality` | 90 | Качество JPEG (1-100, игнорируется для PNG) |
| `--wait` | 1000 | Доп. ожидание после загрузки (мс), для шрифтов и CSS |

## Советы

- Для Retina-качества используй `--scale 2` (по умолчанию) — итоговый файл будет вдвое больше viewport
- Для прозрачных PNG (иконки, стикеры) — `--transparent` + не задавай background на body
- Для JPEG используй расширение `.jpg` — автоматически уберёт альфа-канал
- Для сложной типографики предпочитай Google Fonts — `--wait 2000` чтобы шрифты загрузились
- Справочник техник: `references/css-techniques.md` (от базовой директории скилла)
