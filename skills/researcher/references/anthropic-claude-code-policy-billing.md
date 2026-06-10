# Anthropic / Claude Code: policy + billing research pattern

Кейс: пользователь спрашивает, входит ли Claude Code / Agent SDK / third-party orchestration в подписку, считается ли local tool или MCP отдельным external paid call, и где проходит policy-граница.

## Что проверять
1. `code.claude.com` docs — продуктовая механика, Agent SDK, auth precedence, costs.
2. `support.anthropic.com` / `support.claude.com` — practical billing rules и consumer-plan оговорки.
3. `claude.com/pricing/*` и `docs.anthropic.com` pricing — где заканчивается подписка и начинается API/PAYG.
4. При спорных вопросах — обсуждения/threads только как secondary signal, не как основной источник.

## Ключевые выдержки, найденные в сессии
- Agent SDK docs: third-party developers без approval не должны предлагать `claude.ai` login или rate limits для своих продуктов; рекомендуемый путь — API key auth.
- Claude Code costs docs: для Pro/Max session cost estimate в `/usage` не является биллинговой суммой; usage включен в подписку.
- Help Center: если выставлен `ANTHROPIC_API_KEY`, Claude Code использует API key вместо подписки и usage идет как API charges.
- Help Center: Pro/Max usage limits общие между Claude и Claude Code.
- Help Center: после исчерпания included usage можно включить extra usage, которое идет по standard API rates.

## Рабочая модель ответа
Разделяй ответ на два слоя:
- Billing/auth path: subscription vs API key vs PAYG vs extra usage.
- Tool architecture: local tool, MCP, SDK, external tool, local binary, remote provider.

Частый правильный вывод: вопрос не в том, «external tool» ли это сам по себе, а в том, идет ли сценарий через subscription/OAuth или через API/commercial path.

## Формулировка-предохранитель
Если прямого официального statement нет, пиши не «запрещено/разрешено точно», а:
- что подтверждено официальными docs
- что явно рекомендовано Anthropic
- где остается серая зона интерпретации ToS

## Полезные URL из сессии
- https://code.claude.com/docs/en/agent-sdk/overview
- https://code.claude.com/docs/en/costs
- https://support.anthropic.com/en/articles/11145838-using-claude-code-with-your-pro-or-max-plan
- https://support.anthropic.com/en/articles/12429409
- https://support.anthropic.com/en/articles/8325606-what-is-claude-pro
- https://claude.com/pricing/pro
- https://claude.com/pricing/enterprise
