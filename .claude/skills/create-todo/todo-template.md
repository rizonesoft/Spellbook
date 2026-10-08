---
schema_version: 1
id: CHANGEME-unique-kebab-id
domain: CHANGEME-NN-domain
status: draft
title: "TODO-NN -- CHANGEME Title"
depends_on: []
---

# TODO-NN -- CHANGEME Title

> **Goal:** CHANGEME: one paragraph. What is true when this file is finished, in plain terms.

> [!IMPORTANT]
> **Current state (verified CHANGEME-YYYY-MM-DD):** CHANGEME: what exists RIGHT NOW, before this TODO runs. Name real files and real gaps.

## Inputs

- `CHANGEME/path/or/spec` -- what this TODO consumes from it
- -> XREF: CHANGEME DNN TNN §N -- the related work (the target file must carry an XREF back)

## Outcome

- CHANGEME: an observable end state, not an activity.

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | CHANGEME deliverable | -- |  [ ]   |
|   2   |   §2    | CHANGEME deliverable | §1 |  [ ]   |

---

## 1. CHANGEME Section Title

CHANGEME: one paragraph of context: why this section exists and what it must not break.

- [ ] CHANGEME micro-step in `backtick/path`. Done when: CHANGEME observable end state. Cheaper substitute: CHANGEME the wrong thing.
- [ ] Commit: `"CHANGEME-area: one-line commit message"`

**Test checkpoint:** CHANGEME: the falsifiable command or drive that proves this section. It must be able to fail.

## 2. CHANGEME Surface Section Title

CHANGEME: one paragraph of context.

**Job:** CHANGEME the user can <verb>.
**Treatment:** CHANGEME the asked treatment. Cheaper substitute that fails the checkpoint: CHANGEME.
**Chrome:** consume CHANGEME (the resource-backed vocabulary, WinUI theme, and XAML layout/native pixel boundary). Do not invent a second CHANGEME.

- [ ] CHANGEME micro-step. Done when: CHANGEME.
- [ ] Commit: `"app: CHANGEME"`

**Test checkpoint:** CHANGEME: driven run with evidence (log lines, rows read back, captures under docs/captures/).

## Verification

- [ ] `pwsh scripts/check-all.ps1` exits 0
- [ ] `python scripts/todo-graph.py validate` clean
