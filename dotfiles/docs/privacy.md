# Publication and local data boundaries

## What is shipped

Only selected configuration source files, procedural shaders, reviewed icon assets,
grain PNGs, generated clock sprite sheets, public-source patches, installation tools and documentation.
The export was assembled from specific source directories/file types. It is not a
recursive copy of a home directory or all of `.config`.

Account widgets have no preset username, account identifier, API token, password,
SSH key or remote private service. They are disabled by default and use the
installing user's own CLI authentication only after opt-in. No deployment endpoint
or forwarding service operated by the author receives widget data.

Removed from the public configuration:

- Absolute author-home/project paths, private music catalog/artwork adapter and
  machine-specific mount telemetry.
- Saved wallpaper selections, actual wallpaper collection and runtime UI state.
- Weather locations and personal session identifiers, including sample IDs.
- VPN autostart and bindings, saved network/secret-agent assumptions and personal
  application pins/favorites. Generic editable examples remain.
- Application `.desktop` files, shell aliases, environment snapshots, logs,
  compiled application binaries, browser data, CLI credential stores and caches.

The public source still contains design parameters such as animation durations,
colors and geometry. Those are the desktop configuration being shared, not account
or device credentials. Loopback URLs in the limits adapter address a temporary
local CLI server; provider API URLs are public service endpoints without secrets.

## What becomes private after installation

`integrations.env`, selected wallpaper paths, dock pins, widget caches, session
titles, account balances and provider output belong to the installing user. The
installer keeps live configuration outside the repository. It backs up replaced
directories privately and never uploads their contents. Do not publish those backups.

The local integration file is trusted shell code. Prefer CLI-owned credential
stores rather than API keys in that file, process arguments, screenshots or launch
commands. Never copy `.codex`, `.hermes`, `.config/gh`, `.ssh`, a Vast key file,
password managers or browser profiles into `dotfiles/`.

## Before committing or publishing

Run these from the repository root:

```bash
python3 dotfiles/scripts/check-public.py
# Stage only reviewed publication paths, then inspect the exact index:
python3 dotfiles/scripts/check-public.py --staged
git diff --cached --stat
git diff --cached --check
```

The checker reports locations and categories, never matched secret values. It
detects common credential formats/literals, private IPs, embedded basic-auth URLs,
personal absolute paths, forbidden runtime filenames and unreviewed binaries or
symlinks. It covers `dotfiles/` and the two desktop skills, not unrelated pre-existing
repository content. Generated shader binaries are ignored and must not be staged.

This is a guard, not proof of the absence of all secrets. Also review the staged
diff, hardcoded domains/commands, sample data and image provenance. Never commit
raw machine files first and try to remove secrets in a later commit: history would
already contain them. Do not include screenshots showing accounts, notifications,
session titles, codes or balances in a public release without deliberate redaction.
