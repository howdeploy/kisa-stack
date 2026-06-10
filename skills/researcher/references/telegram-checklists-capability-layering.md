# Telegram checklists vs Hermes vs skills

Короткая опорная заметка для capability-ресёрча по Telegram/Hermes.

## Проверочная рамка
Разделяй 4 слоя:
1. **Upstream API** — что вообще позволяет Telegram Bot API.
2. **SDK layer** — есть ли методы/типы в установленной библиотеке.
3. **Local integration** — использует ли это текущий Hermes gateway/tooling.
4. **Skill boundary** — достаточно ли skill, или нужен новый tool/gateway/MCP.

## Что подтвердилось в этой сессии
- В Telegram Bot API есть нативные checklist-объекты.
- В установленном `python-telegram-bot 22.7` присутствуют:
  - `Bot.send_checklist`
  - `Bot.edit_message_checklist`
  - `telegram.InputChecklist`
  - `telegram.Checklist`
  - `telegram.ChecklistTask`
- Сигнатура `send_checklist(...)` требует `business_connection_id`.
- В локальном Hermes Telegram adapter основной путь отправки — обычный `send_message`, а не checklist-specific methods.
- При этом Hermes adapter уже умеет `InlineKeyboardMarkup` / `InlineKeyboardButton`, approvals, confirm и clarify callbacks.

## Практический вывод
- Формулировка уровня **«Telegram умеет»** не равна **«Hermes уже это экспонирует»**.
- Формулировка уровня **«библиотека поддерживает»** не равна **«локальный продукт wired up»**.
- Формулировка уровня **«можно сделать skill»** не равна **«skill alone достаточно»**.

## Хороший шаблон ответа
- `Да, API умеет, но Hermes сейчас это не вывел.`
- `Да, это можно реализовать, но не одним skill.`
- `Лучший practical путь может быть не нативный checklist, а UX на inline buttons.`

## Реалистичные implementation paths
1. **Inline-button pseudo-checklist** в Hermes Telegram gateway:
   - не нативный checklist object;
   - зато не упирается в business-account path;
   - хорошо подходит для personal task UX.
2. **Нативный checklist path**:
   - требует поддержки `send_checklist` / `edit_message_checklist` в gateway/tool;
   - вероятно требует business account / `business_connection_id` контура.
3. **Внешний MCP/custom tool**:
   - Hermes вызывает отдельный tool, который общается с Bot API;
   - skill здесь только orchestration layer.

## Pitfall
Нельзя обещать пользователю, что `skill` сам по себе добавит новый тип Telegram-сообщения. Если нужен новый transport primitive, это уже не уровень skill-инструкции, а уровень tooling/integration.
