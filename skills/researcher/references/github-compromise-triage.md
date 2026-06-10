# GitHub compromise triage — concise field notes

Use when the user asks whether a GitHub-related compromise is real, current, or relevant to them.

## Core distinction
Do not collapse everything into "GitHub was hacked". Split the incident class first:
- GitHub platform compromise
- GitHub account compromise
- stolen PAT / OAuth token / session
- compromised third-party OAuth app or integrator
- GitHub Actions / OIDC / workflow trust-boundary abuse
- supply-chain package compromise that steals GitHub credentials

## Strong sources to prefer
1. GitHub Docs
2. GitHub Blog / incident/security post
3. First-party project postmortem / advisory
4. Strong secondary analysis only after the above

## Confirmed sources used in this session
- GitHub Docs: securing accounts
- GitHub Docs: reviewing authorized OAuth apps
- GitHub Docs: org audit log
- GitHub Docs: Actions secure use
- GitHub Docs: secret scanning
- GitHub Blog: stolen OAuth user tokens issued to Heroku / Travis CI
- TanStack postmortem on npm supply-chain compromise

## Practical triage checklist
### Account / org
- Review Authorized OAuth Apps
- Review PATs and revoke stale / broad tokens
- If you own an org: inspect Audit log with a date filter
- Review Members and Outside collaborators for unexpected additions

### Actions / CI
- Inspect successful and failed runs from suspicious refs
- Look for unexpected workflow changes under `.github/workflows/`
- Watch for `pull_request_target`, overbroad permissions, unpinned actions, deploy/publish jobs from odd branches

### Supply chain
- Search lockfiles for affected package families
- In this session, high-signal families were:
  - `@tanstack/*`
  - `@antv/*`
  - `guardrails-ai` (PyPI signal)
- `durabletask` was not confirmed from quick research and should be treated as unconfirmed until stronger evidence appears

### Phishing / notifications
- Check recent GitHub-themed emails manually
- Prefer opening GitHub directly instead of following links from email
- Treat "your repositories" / urgent verification mails as suspicious until verified in the UI

## Useful GitHub UI / query hints
### Org audit log
- `created:>=YYYY-MM-DD`
- `operation:access created:>=YYYY-MM-DD`
- `repo:ORG/REPO created:>=YYYY-MM-DD`
- `actor:USERNAME created:>=YYYY-MM-DD`

## Answer shape that worked well
1. Say whether the checklist is still relevant
2. Split confirmed vs unconfirmed indicators
3. Give exact UI locations or grep/ripgrep commands
4. End with a priority order of checks
