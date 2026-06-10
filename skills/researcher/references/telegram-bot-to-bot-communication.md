# Telegram Bot-to-Bot Communication (official doc note)

Source:
- https://core.telegram.org/bots/features#bot-to-bot-communication

## What the official docs say
- Telegram bots usually **cannot see messages from other bots** by default.
- **Bot-to-Bot Communication Mode** must be enabled in **@BotFather** to use the feature fully.
- In **group chats**, one bot can reach another by:
  - sending a command like `/command@OtherBot`
  - replying directly to the other bot's message
- If **at least one** of the two bots has Bot-to-Bot Communication Mode enabled, the **receiving bot should get the message** and can respond.
- Bots with Bot-to-Bot mode enabled can receive **all** messages from other bots in groups **without explicit mention/reply** if they either:
  - are **admins** in the group, or
  - have **Group Privacy Mode disabled**
- In **private chats**, bot-to-bot DM requires Bot-to-Bot mode enabled for **both** sender and recipient.
- Telegram explicitly warns about **infinite interaction loops** and recommends:
  - deduplication
  - rate limits
  - max depth / timeout safeguards

## Practical takeaway for research / troubleshooting
When someone says "bot A pings bot B in a group but nothing arrives", separate the problem into these checks:
1. Is the message using an allowed path (`/command@OtherBot` or direct reply)?
2. Is Bot-to-Bot Communication Mode enabled in BotFather on one or both bots as required by the context?
3. For passive group reception without mention/reply, is the receiving bot admin or privacy-disabled?
4. Is there app-side loop protection or allowlisting that may discard the update after delivery?

## Extraction note
The main `web_extract` result for `core.telegram.org/bots/features` may summarize the entire feature page and blur the specific anchor section. If the user needs the exact Bot-to-Bot rules, pull the page HTML and isolate the `#bot-to-bot-communication` anchor block locally.