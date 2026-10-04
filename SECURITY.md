# Security Policy

## Supported versions

Spellbook is pre-alpha and has no release yet. Once releases begin, security fixes go into the latest release.

| Version | Supported |
| ------- | --------- |
| Latest `v*` release | Yes |
| Older releases and unreleased builds from `main` | Best effort |

## Reporting a vulnerability

**Please do not report security vulnerabilities through public issues, discussions, or pull requests.**

Report them privately through GitHub's private vulnerability reporting:

1. Open the [Security tab](https://github.com/rizonesoft/Spellbook/security) of this repository.
2. Choose **Report a vulnerability** ([direct link](https://github.com/rizonesoft/Spellbook/security/advisories/new)).
3. Fill in the advisory form.

Helpful details to include:

- The version or commit
- The type of issue, for example a crash or memory corruption when importing a crafted `.txt` file, or a database file that makes Spellbook misbehave
- Steps to reproduce, and a sample file if the issue is triggered by opening or importing one (attach it to the private advisory, never to a public issue)
- The impact as you understand it

## What Spellbook does and does not do

- Spellbook makes **no network calls**. Prompts stay in `%LOCALAPPDATA%\Spellbook\spellbook.db` on your machine.
- The database is **not encrypted**: anyone who can read your user profile can read your prompts. Do not store secrets (API keys, passwords) in prompts.
- The log never records prompt text, only actions, ids, and file paths.
- The most likely attack surface is input Spellbook parses: imported `.txt` files (M2) and restored backups (M5).

## What to expect

- We aim to acknowledge a report within **7 days**, keep you updated in the advisory, and credit you when the fix ships unless you prefer to stay anonymous.
- This is a small open source project, so timelines are goals rather than guarantees. Please give us a reasonable chance to release a fix before discussing the issue publicly.

## Code signing

Release binaries are not code-signed yet. Check a download against the `SHA256SUMS` file attached to the same [GitHub release](https://github.com/rizonesoft/Spellbook/releases) before running it.
