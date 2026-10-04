---
schema_version: 1
id: first-run
domain: 05-ship
status: draft
title: "TODO-04 -- First Run: the Starter Grimoire, the Welcome Tour, About, and What's New"
depends_on: []
---

# TODO-04 -- First Run: the Starter Grimoire, the Welcome Tour, About, and What's New

> **Goal:** The first minute sells the app: an empty library opens on a welcome page that offers to import the user's `.txt` prompts, add a starter grimoire of genuinely useful spells, or start empty; a short tour points at the four things that matter; the About dialog credits every component and its license; and after an update a What's New InfoBar says what changed.

> [!IMPORTANT]
> **Current state (verified 2026-10-04):** Nothing here exists. Operator decision 2026-10-04 (ADR 0003): a starter grimoire and a short tour are in v0.1.0. The starter content is a `.spell` file (`D02 T02 §1`) that demonstrates runes, rich runes, and composition (`D04 T02`), written by the implementing agent under CC0 so users may copy it freely. Third-party notices are required by the licenses of SQLite (public domain, credited anyway), spdlog, fmt, nlohmann-json, Catch2 (tests only, not shipped), and the Windows App SDK (MIT).

## Inputs

- -> XREF: D02 T02 §1 -- the `.spell` format the starter grimoire ships in
- -> XREF: D04 T02 §2 -- composition, which the starter grimoire demonstrates
- -> XREF: D02 T01 §4 -- Import scrolls, the first choice on the welcome page
- -> XREF: D03 T01 §6 -- the hotkey the tour teaches
- Microsoft Learn: `TeachingTip`, `ContentDialog`, `InfoBar` (WinUI 3)
- -> XREF: D05 T02 §2 -- the installer ships `THIRD-PARTY-NOTICES.txt`

## Outcome

- An empty library shows the welcome page; each of its three choices works; the tour runs once and can be replayed from Help.
- `resources/starter-grimoire.spell` holds at least 24 spells in 6 chapters, each with a description, a target model of "Any", and at least a third using runes, choices, or includes.
- About lists the version, the license, the publisher, and every shipped component with its license text in `THIRD-PARTY-NOTICES.txt`, which the installer and the ZIP also ship.
- The first start after an upgrade shows What's New with that version's changelog section.

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | The starter grimoire | D02 T02 §1, D04 T02 §2 |  [ ]   |
|   2   |   §2    | The welcome page and the tour | §1, D02 T01 §4, D03 T01 §6, D02 T02 §2 |  [ ]   |
|   3   |   §3    | About, third-party notices, and What's New | D05 T01 §2 |  [ ]   |
|   4   |   §4    | The first-run guide | §2, §3 |  [ ]   |

---

## 1. The Starter Grimoire

- [ ] `resources/starter-grimoire.spell`: chapters Writing, Coding, Analysis, Research, Learning, and Everyday, at least four spells each, every one useful as written (no lorem ipsum, no placeholders a user must rewrite), with descriptions; at least eight use runes (including a choice and a long rune) and at least two include a shared "House style" spell. Done when: `read_spell_file` loads it with no error.
- [ ] `resources/README.md` states the content is CC0 1.0 and how to edit it. Done when: present.
- [ ] A core test parses the grimoire, renders every spell with its defaults, and asserts no missing include and no literal-fallback rune. Done when: it passes.
- [ ] Commit: `"resources: the starter grimoire (D05 T04 §1)"`

**Test checkpoint:** Unit test: `pwsh scripts/test.ps1 -Filter "core: .*starter"` passes.

## 2. The Welcome Page and the Tour

**Job:** a new user gets from install to a useful library in under a minute.
**Treatment:** with no spells (and no spells in Trash), the main area shows a welcome page: the logo, one sentence, and three cards: "Bring in my .txt prompts" (opens Import scrolls), "Add the starter grimoire" (imports `starter-grimoire.spell` as an undoable batch into a "Starter" chapter), and "Start empty". After the first choice, a four-step `TeachingTip` tour: the chapters tree, the spell list, the editor (autosave), and the hotkey (Win+Shift+Space, with Cast). Help > Show the tour replays it. Cheaper substitute that fails the checkpoint: an empty window with a text hint.
**Chrome:** consume Import scrolls, the `.spell` import path of `D02 T02 §2`, the vocabulary table, and the brand icon from `assets/brand/`. Do not add a separate first-run window.

- [ ] The welcome page (AutomationIds `welcome`, `welcome-import`, `welcome-starter`, `welcome-empty`) and the tour (`tour-step-1` to `tour-step-4`, Next, Skip); "tour shown" is stored in settings. Done when: each choice works and the tour shows once.
- [ ] `tests/ui/scenarios/first-run.ps1`: launch on an empty data folder, choose the starter grimoire, step through the tour, assert the spell count via `dbread.py`, relaunch and assert no tour; undo the import and assert the welcome page returns. Done when: it exits 0.
- [ ] Commit: `"app: the welcome page and the tour (D05 T04 §2)"`

**Test checkpoint:** Driven run with evidence: `pwsh scripts/drive.ps1 -Scenario first-run` exits 0; captures of the welcome page and a tour step under `docs/captures/first-run/`.

## 3. About, Third-Party Notices, and What's New

**Job:** the user knows what they are running, who made it, and what changed.
**Treatment:** Help > About Spellbook: icon, name, version (with "portable" when it is), "A Rizonesoft app", the copyright line, MIT license, links to the website, the repository, and the privacy page, and a "Third-party notices" expander showing `THIRD-PARTY-NOTICES.txt`. After the version changes, the first start shows an InfoBar "Updated to <version>" with "What's new", which opens that version's section of the bundled `CHANGELOG.md`. Cheaper substitute that fails the checkpoint: a message box with the version.
**Chrome:** consume `spellbook::core::version`, the settings store (last-seen version), and the theme resources. Do not fetch release notes from the network.

- [ ] `THIRD-PARTY-NOTICES.txt` at the repository root: every component linked into `Spellbook.exe` or shipped beside it, with its license text, generated by `scripts/third-party-notices.py` from `vcpkg.json`, the vcpkg `installed/.../share/<port>/copyright` files, and the Windows App SDK package license. `package.ps1` and the installer ship it. Done when: the script's output matches the committed file (a check in `check-all.ps1`).
- [ ] `src/core/include/spellbook/core/changelog.hpp`: `section_for_version(std::string_view changelog, SemVer) -> std::optional<std::string>`. Done when: tests cover a present version, an absent one, and `Unreleased`.
- [ ] The About dialog and the What's New InfoBar (AutomationIds `about`, `about-notices`, `whats-new`). Done when: both shown in a driven run (the scenario fakes an upgrade by editing the stored last-seen version).
- [ ] `tests/ui/scenarios/about.ps1`. Done when: it exits 0.
- [ ] Commit: `"app: About, third-party notices, and What's New (D05 T04 §3)"`

**Test checkpoint:** Driven run with evidence: `pwsh scripts/drive.ps1 -Scenario about` exits 0; the notices check passes in `check-all.ps1`.

## 4. The First-Run Guide

- [ ] `docs/user/getting-started.md`: install, the welcome page, the tour, the starter grimoire; README Quick start points to it. Done when: linked from `docs/user/README.md`.
- [ ] `CHANGELOG.md` Unreleased lists the welcome page, the starter grimoire, About, and What's New. Done when: present.
- [ ] Commit: `"docs: getting started (D05 T04 §4)"`

**Test checkpoint:** Static evidence: `python scripts/check-docs.py` prints `0 findings`.

## Verification

- [ ] `pwsh scripts/check-all.ps1` exits 0
- [ ] `pwsh scripts/drive.ps1 -Scenario first-run` and `about` exit 0
- [ ] `python scripts/todo-graph.py validate` clean
