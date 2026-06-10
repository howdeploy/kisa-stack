# GSD / Get Shit Done rug-pull research notes

Concise source map for future research on the GSD controversy. Use this as a starting reference, not as a substitute for fresh verification.

## Scope split
Always separate these entities:
- **Tool/codebase**: Get Shit Done / GSD AI tool
- **Old repo/publisher path**: original maintainer-controlled repo/packages
- **Community continuation**: `open-gsd/get-shit-done-redux` and `open-gsd`
- **Token**: `$GSD` on Solana
- **Accused founder identity in public discussion**: `@official_taches`, Lex Christopherson / TÂCHES / related old maintainer identity claims

## Strong direct sources
### Community fork / migration / trust crisis
- Repo: `https://github.com/open-gsd/get-shit-done-redux`
- Discussion: `https://github.com/open-gsd/get-shit-done-redux/discussions/1`
- Discussion: `https://github.com/open-gsd/get-shit-done-redux/discussions/109`

What these establish reliably:
- the community fork happened;
- maintainers framed the event as a major trust/ownership crisis;
- they warned users to migrate away from the old ecosystem;
- they stated they did **not** have evidence that the codebase itself had already been backdoored;
- they treated old publisher/package control as the core supply-chain risk.

What they do **not** by themselves prove:
- final on-chain attribution to a specific founder wallet;
- exact loss amount;
- a complete forensic chain proving who executed token dumps.

## Reddit warning thread
- Thread: `https://old.reddit.com/r/ClaudeAI/comments/1tktl4w/if_you_use_the_get_shit_done_gsd_ai_tool_you_need/`

Use `old.reddit.com` for extractability.

What the thread is good for:
- capturing the community security posture: migrate immediately, uninstall old packages, treat old maintainer-controlled publish path as unsafe;
- collecting links to fork discussions, audit claims, and migration commands.

What the thread is **not**:
- not a standalone forensic proof dossier;
- not sufficient by itself to prove exact theft amount or definitive personal attribution.

## Secondary sources repeating the allegation
- AI Weekly: `https://aiweekly.co/alerts/get-shit-done-creator-rug-pulls-gsd-token-vanishes`
- Our Crypto Talk: `https://ourcryptotalk.com/news/bags-hackathon-winner-gsd-cloud-rug-pull`
- Search snippets / X references often quote claims like deleted accounts, sold holdings, extracted about `$500K`.

Use these for:
- confirming that the allegation spread broadly;
- comparing repeated claims and wording.

Do **not** treat them as independent proof of:
- exact amount;
- exact wallet attribution;
- whether it was founder exit, cofounder/operator action, or account takeover.

## Token reference seen in prior research
- Phantom page: `https://phantom.com/tokens/solana/8116V1BW9zaXUM6pVhWVaAduKrLcEBi3RGXedKTrBAGS`

This is useful for confirming the token exists / market context, but by itself it does not prove rug-pull attribution.

## Recommended answer shape
For future user-facing writeups, use this structure:
1. First-line verdict: strong evidence of a trust/supply-chain crisis around the old GSD ecosystem.
2. Separate **product risk** from **token-rug claim**.
3. State clearly:
   - confirmed directly by repo/fork/discussions;
   - supported by strong secondary coverage;
   - still unproven without full on-chain forensic attribution.
4. If the user asks whether to keep using the old tool, emphasize the supply-chain answer first: old publisher control is enough reason to migrate even without perfect rug-pull attribution.
