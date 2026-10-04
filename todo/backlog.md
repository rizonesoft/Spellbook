# Backlog

Ideas worth keeping that are not planned work. Nothing here is runnable, and no section defers to it. An entry leaves only by promotion (`add-todo` turns it into a section and deletes the line) or with the operator's words recorded under "Removed with operator approval". Format, as Isotone's:

```
- [B-NNN] <title> -- source: <key> -- added: YYYY-MM-DD -- why deferred: <text> -- promote when: <text>
```

## Entries

- [B-001] A MySQL 8 backend behind IPromptRepository -- source: brief-storage-alternative -- added: 2026-10-04 -- why deferred: the brief chose SQLite; a server adds setup, credentials, and a network dependency for one user -- promote when: Spellbook needs a shared library across machines or users
- [B-002] Sync between machines through a user-chosen folder (OneDrive, Dropbox) -- source: idea-folder-sync -- added: 2026-10-04 -- why deferred: no network or sync for v0.1.0; SQLite files must not be synced live -- promote when: the operator uses Spellbook on a second machine
- [B-003] Send a cast prompt straight to an AI app or API -- source: idea-direct-send -- added: 2026-10-04 -- why deferred: the operator chose "No, clipboard only" on 2026-10-04 (ADR 0003) -- promote when: the operator asks for it
- [B-004] Localised UI strings beyond English -- source: idea-localisation -- added: 2026-10-04 -- why deferred: the vocabulary table (D01 T01 §4) is the seam; translations need a reviewer per language -- promote when: a translator volunteers
- [B-006] Code signing for the installer and exe -- source: idea-signing -- added: 2026-10-04 -- why deferred: no certificate yet (Isotone has the same gap) -- promote when: a certificate exists

- [B-007] Cast-and-paste: Enter in the popup pastes into the previous app -- source: premium-cast-and-paste -- added: 2026-10-04 -- why deferred: offered on 2026-10-04 and not chosen for v0.1.0 -- promote when: the operator asks for it
- [B-008] A command palette (Ctrl+K) over every command and spell -- source: premium-command-palette -- added: 2026-10-04 -- why deferred: offered on 2026-10-04 and not chosen for v0.1.0 -- promote when: the operator asks for it
- [B-009] Saved searches as smart collections in the tree -- source: premium-saved-searches -- added: 2026-10-04 -- why deferred: offered on 2026-10-04 and not chosen for v0.1.0 -- promote when: the operator asks for it
- [B-010] Test run: run a spell against one or more models and compare the answers -- source: ai-test-run -- added: 2026-10-04 -- why deferred: offered on 2026-10-04 and not chosen for v0.1.0 -- promote when: the operator asks for it
- [B-011] Clean-machine install tests in Windows Sandbox -- source: install-tests-sandbox -- added: 2026-10-04 -- why deferred: the operator chose tests on the development PC (ADR 0003) -- promote when: the operator enables Windows Sandbox

## Removed with operator approval
