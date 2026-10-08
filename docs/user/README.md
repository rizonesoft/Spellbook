# Spellbook User Guide

How to use Spellbook. Spellbook is pre-alpha: this guide grows with each milestone, and a page appears here when the feature it describes works.

## Getting started

- **Install:** there is no release yet; build from source as described in the [README](../../README.md#build-from-source). From v0.1.0 there will be an installer and a portable ZIP.
- **Start:** run `Spellbook.exe` from its complete application folder. Keep its DLLs, resources, and icon beside it when copying the app. The first launch creates your library in `%LOCALAPPDATA%\Spellbook\`.
- **What you see today:** a WinUI window titled Spellbook, with a themed title bar, Mica backdrop where Windows supports it, and the message "Your grimoire is ready". Storing and editing prompts arrives in M1.

## Where your data lives

| Path | What |
| ---- | ---- |
| `%LOCALAPPDATA%\Spellbook\spellbook.db` | Your library: every prompt, folder, tag, and revision, in one SQLite file. Back it up by copying it while Spellbook is closed (an export to JSON arrives in M5). |
| `%LOCALAPPDATA%\Spellbook\logs\spellbook.log` | What Spellbook did, for troubleshooting. It names actions and files, never the text of your prompts. |

Spellbook never connects to the network and keeps nothing anywhere else.

## The words Spellbook uses

| You see | It means |
| ------- | -------- |
| Spell | A saved prompt |
| Chapter | A folder of prompts |
| Sigil | A tag |
| Cast (Ctrl+Enter) | Copy the prompt to the clipboard, with its variables filled in |
| Rune (`{{name}}`) | A template variable |
| Revisions | Version history |
| Import scrolls | Import `.txt` files |

Hover over any themed label to see its plain meaning. A setting (M5) switches every label to the plain words.

## Coming next

| Guide | Arrives with |
| ----- | ------------ |
| The library: spells, chapters, the editor, autosave | M1 |
| Importing your `.txt` prompt files | M2 |
| Finding and casting: search, sigils, favourites, the quick-search popup | M3 |
| Runes and revisions | M4 |
| Settings, themes, export, and restore | M5 |

## Troubleshooting

If Spellbook will not start, it shows a message saying what failed. The last lines of `%LOCALAPPDATA%\Spellbook\logs\spellbook.log` say more; include them when you [report a bug](https://github.com/rizonesoft/Spellbook/issues/new?template=bug_report.yml).
