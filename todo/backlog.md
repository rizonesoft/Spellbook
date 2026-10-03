# Backlog

Ideas worth keeping that are not planned work. Nothing here is runnable, and no section defers to it. An entry leaves only by promotion (`add-todo` turns it into a section and deletes the line) or with the operator's words recorded under "Removed with operator approval". Format, as Isotone's:

```
- [B-NNN] <title> -- source: <key> -- added: YYYY-MM-DD -- why deferred: <text> -- promote when: <text>
```

## Entries

- [B-001] A MySQL 8 backend behind IPromptRepository -- source: brief-storage-alternative -- added: 2026-10-04 -- why deferred: the brief chose SQLite; a server adds setup, credentials, and a network dependency for one user -- promote when: Spellbook needs a shared library across machines or users
- [B-002] Sync between machines through a user-chosen folder (OneDrive, Dropbox) -- source: idea-folder-sync -- added: 2026-10-04 -- why deferred: no network or sync for v0.1.0; SQLite files must not be synced live -- promote when: the operator uses Spellbook on a second machine
- [B-003] Send a cast prompt straight to an AI app or API -- source: idea-direct-send -- added: 2026-10-04 -- why deferred: no network calls in v0.1.0 -- promote when: the clipboard round trip becomes the bottleneck
- [B-004] Localised UI strings beyond English -- source: idea-localisation -- added: 2026-10-04 -- why deferred: the vocabulary table (D01 T01 §4) is the seam; translations need a reviewer per language -- promote when: a translator volunteers
- [B-005] winget package -- source: idea-winget -- added: 2026-10-04 -- why deferred: needs a stable release and installer first -- promote when: v0.1.0 has shipped
- [B-006] Code signing for the installer and exe -- source: idea-signing -- added: 2026-10-04 -- why deferred: no certificate yet (Isotone has the same gap) -- promote when: a certificate exists

## Removed with operator approval
