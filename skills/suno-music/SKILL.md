---
name: suno-music
description: "Generate instrumental background music and songs via EvoLink Suno API, with special handling for voiceover-safe tracks."
tags: [music, audio, generation, suno, evolink, telegram]
platforms: [linux]
metadata:
  hermes:
    tags: [music, audio, generation, suno, evolink, telegram]
    related_skills: [ai-music-and-audio-tools]
---

# Suno Music Generation Skill

> **Примечание по среде.** Скилл писался в среде Hermes: отправка в Telegram и формат `MEDIA:/path` — ее конвенции доставки. В Claude Code / Codex просто сохрани файл и отдай пользователю абсолютный путь.

## Описание
Генерация музыки через EvoLink Suno API. Подходит и для обычных треков по описанию, и для более точных фоновых underscore-треков под ролики, voiceover и объясняющие видео.

## Когда использовать
- пользователь просит создать трек или музыку
- нужен нейтральный фон под ролик, подкаст, объяснялку, видеоэссе
- нужно быстро получить несколько вариантов одной музыкальной идеи
- упоминаются `suno`, `музыка`, `трек`, `фон`, `саундтрек`

## Триггеры (автоматическое определение)
- "создай трек"
- "сгенерируй музыку" / "сделай песню"
- "музыка под настроение"
- "хочу послушать музыку"
- "давай сделаем трек"
- упоминание "suno"

## Workflow (упрощенный)
1. Пользователь просит трек человеческим языком
2. Я коротко подтверждаю и сразу генерирую
3. Собираю промпт автоматически или вручную, если нужен более точный результат
4. Отправляю запрос в API
5. Жду завершения задачи и скачиваю файл
6. Если прямой Telegram target настроен — отправляю MP3
7. Если target не настроен или встроенная отправка недоступна — возвращаю файл через `MEDIA:/absolute/path`

## API
- **Base URL:** `https://api.evolink.ai/v1`
- **Endpoint:** `/audios/generations`
- **Auth:** Bearer token в заголовке
- **API Key:** хранится в файле `.env` в директории скилла (см. `.env.example`)

## Базовый workflow
1. Получаю запрос пользователя
2. Собираю промпт: жанр, настроение, BPM, инструменты, ограничения
3. POST на `/v1/audios/generations`
4. Получаю `task_id`
5. Polling `/v1/tasks/{task_id}` каждые 5 секунд
6. Когда `status == "completed"` — скачиваю audio URL
7. Возвращаю готовый файл пользователю

## Параметры генерации
- `model`: `suno-v5` (по умолчанию; при необходимости можно пробовать другие)
- `prompt`: текстовое описание трека
- `custom`: true/false
- `lyrics`: текст песни, если нужна песня, а не инструментал

## Время генерации
Обычно ~20–30 секунд на трек, но с очередью может быть дольше. Закладывать до нескольких минут.

## Формат ответа
- обычный путь: MP3/WAV отправляется пользователю
- fallback-путь: вернуть `MEDIA:/absolute/path` в сообщении, если прямой target Telegram не определен

## Важный режим: фон под озвучку / YouTube voiceover
Когда пользователь просит **нейтральный фон под ролик, объяснялку, документальный тех-разбор, voiceover, YouTube essay**, не полагаться только на широкие жанровые ярлыки вроде `lo-fi` или `electronic`.

В таком случае промпт лучше строить вокруг функции трека:
- `instrumental only`
- `background underscore for spoken-word / voiceover`
- `neutral`, `unobtrusive`, `low emotional intensity`
- `no vocals`
- `no strong melody`
- `no dramatic drops`
- `no aggressive drums`
- `designed to sit behind narration`

Это сильно повышает шанс получить реально пригодный фон, а не просто «приятную музыку».

## Рекомендуемые семейства для тех-роликов и explainers
### 1. Minimal ambient tech
Хорошо подходит, когда нужен самый прозрачный и умный фон.

Опорные элементы:
- soft warm pads
- subtle low pulse
- gentle air texture
- very slow harmonic movement

Если пользователь любит ambient, но раздражается от «звонких» деталей, не добавляй `glassy plucks`, `sparkle`, `chimes` или яркие верхние акценты по умолчанию.

### 2. Light documentary modular electronics
Хорошо подходит, когда хочется чуть больше структуры и инженерного ощущения, но без тревоги.

Опорные элементы:
- soft modular pulses
- muted percussive ticks
- restrained bass support
- minimal arpeggio or sequencer motion
- clean documentary feel

Если первая версия кажется слишком технологичной, смещайся от `modular` и `futuristic` к `neutral documentary`, `human`, `warm`, `matte`, `soft`, `rounded`.

### 3. Matte neutral explainer bed
Это полезный refinement-режим, когда пользователю в целом нравится документальный фон, но бесят звонкие или цепляющие элементы.

Опорные элементы:
- matte / rounded / soft tone
- low-key synth bed
- muted low pulse
- gentle bass support
- blurred or diffuse texture
- no memorable top-end details

Особенно полезно для YouTube-роликов, где трек должен буквально исчезать под речью.

### 4. Muted synthwave / soft outrun voiceover bed
Это refinement-режим для случая, когда полностью нейтральные documentary/corporate bed'ы оказываются **слишком безликими**, а пользователю на самом деле нужен не просто фон, а **конкретный звуковой мир**.

Ключевой урок из этой сессии: пользователь может жаловаться, что трек "не звучит как нейтральная фоновая музыка под видос", но реальная проблема не в избытке жанра, а в **нехватке правильного synthwave-вайба**.

Рабочая формула:
- synthwave / outrun timbre
- muted / restrained arrangement
- soft analog pads
- soft synth bass
- gentle retro pulse
- no lead melody
- no heroic hook
- no sax
- no bright arpeggio showcase
- no big snare fills
- no cinematic rise
- smooth unobtrusive mix under narration

Это не "сделай чистый synthwave-трек", а **"сделай synthwave, который знает свое место под голосом"**.
## Практический паттерн вариантов
Если пользователь просит несколько версий фона под одно видео, хороший рабочий набор такой:
- 1 версия **minimal ambient tech**
- 2 версии **documentary/modular electronics**

Менять между версиями лучше не все сразу, а:
- плотность ритма
- заметность pulse/sequencer motion
- ширину и воздух
- степень «документальности» против «эмбиентности»

## Автоматическая генерация промптов
Скилл может сам определить:
- жанр (например: лоу-фай, электроника, ambient)
- настроение (спокойный, энергичный, меланхоличный)
- BPM
- дополнительные параметры (pads, vocals, atmosphere)

Но если задача узкая — например, **фон под речь** — лучше вручную уточнять промпт, а не надеяться только на keyword-автоматику.

## Seamless loop mode for video backgrounds
Когда пользователь просит фон, который потом будут **растягивать под любую длину видео**, трактуй это как отдельный режим, а не как обычный трек.

Что нужно прямо зашивать в промпт:
- `instrumental only`
- `seamless loop` / `seamless looping`
- `loopable background bed`
- `written as a perfectly loopable 8-bar or 16-bar cycle`
- `no hard intro`
- `no hard outro`
- `no fade-out`
- `matching start and end energy`
- `stable harmony`
- `smooth loop transition`
- `designed to sit under voiceover`

Практический вывод: для loopable-фона не проси «песню». Проси **bed / underscore / background loop**, иначе модель слишком легко делает законченный музыкальный трек с нормальным вступлением и финалом.

Особенно хорошо работает такой тройной набор вариантов:
- muted chill synthwave underscore
- cold melancholic soviet-wave bed
- soft retro ambient synth loop

## Pitfalls
- Не отправляй только жанровой запрос вроде `electronic ambient` для voiceover-задачи — часто выйдет слишком музыкально и заметно.
- Не используй яркую мелодию, вокальные chops или агрессивные барабаны для объясняющего ролика.
- Если пользователь жалуется на «звонкие» звуки, убирай из промпта все bright/glassy/chime/pluck/sparkle/metallic и прямо прописывай: `no bright elements`, `no ringing overtones`, `no shimmering top end`, `matte`, `rounded`, `soft`.
- Если первая генерация все равно звучит слишком технологично или мягко «не туда», делай не жанровый прыжок, а маленький refinement вокруг понравившейся версии: теплее/суше/темнее/без пульса/без верха.
- Если после нескольких итераций нейтральный фон кажется пользователю слишком библиотечным, безликим или «не как настоящий вайб», проверь обратную гипотезу: возможно, ему нужен не еще более стерильный bed, а **узнаваемая жанровая окраска** с жестко приглушенной аранжировкой. Хороший частный ход — muted synthwave / soft outrun вместо дальнейшего сползания в corporate stock music.
- Если API отвечает 400 на сложный промпт в non-custom mode, помни конкретное ограничение: **примерно 500 символов максимум**. Для background-генерации лучше писать компактно и без повторов, чем длинным литературным абзацем.
- Если URL из EvoLink/Suno media CDN дает 403 при скачивании через `urllib` или похожий голый HTTP-клиент, повтори скачивание через `curl -L --fail`. У этих ссылок бывают капризные CDN/redirect-пути, где `curl` проходит стабильнее.
- Не обещай прямую отправку в Telegram, если target не настроен. В таком случае отдай файл через `MEDIA:/...`.
- Если нужен выбор, лучше сделать 3 близких варианта одной концепции, чем 3 радикально разных жанра.

## References
- `references/voiceover-background-prompts.md` — компактный банк промптов и refinement-эвристик для нейтрального фона под речь, explainers и YouTube-ролики.
- `references/vpn-cyber-tech-prompts.md` — готовые prompt families для VPN / privacy / cyber / AI-tech роликов: темный glitch-cinematic и более ритмичный cyber-pulse.
- `references/loopable-video-background-prompts.md` — короткие рабочие prompt families для seamless loop фонов под ролики: synthwave, soviet-wave и ambient bed.

## Интеграция в основную систему
Типовой flow:
1. понять, нужен ли обычный трек или фон под narration
2. при необходимости вручную переписать промпт под underscore-задачу
3. если пользователь уже выбрал «почти подходящий» трек, делать 2–3 близких refinement-варианта вокруг него, а не уходить в новый жанр
4. запустить генерацию
5. скачать результат
6. доставить через Telegram или `MEDIA:/...` fallback
