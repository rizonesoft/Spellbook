# Documentation

| Section | For | Start here |
| ------- | --- | ---------- |
| [User guide](user/README.md) | People using Spellbook | Where your data lives, the vocabulary, what works today |
| [Architecture](architecture.md) | Contributors | The three layers, startup, storage and migrations, the Win32 shell |
| [Building](dev/build.md) | Contributors | The toolchain, building, testing, the gates, CI, troubleshooting |
| [Decisions](adr/0001-tech-stack.md) | Anyone asking "why" | ADR 0001: the tech stack, the alternatives, and the packaging choice |
| [Reference conventions](reference-conventions.md) | Maintainers | What Spellbook copied from Isotone, Resolute, and ScratchPad, and every divergence |
| [Captures](captures/) | Reviewers | Screenshots recorded as evidence by plan sections |

Elsewhere in the repository:

- [README](../README.md): what Spellbook is, status, and quick start
- [AGENTS.md](../AGENTS.md): the rules agents and contributors work by
- [standards/](../standards/README.md): C++, UI, testing, and release standards
- [todo/](../todo/README.md): the development plan
- [CONTRIBUTING.md](../CONTRIBUTING.md), [CHANGELOG.md](../CHANGELOG.md), [SECURITY.md](../SECURITY.md)

## Writing docs

- User-visible changes update or add a page in [`user/`](user/README.md) in the same commit.
- Architecture, build, or process changes update this folder.
- A decision with alternatives worth remembering gets the next ADR: `adr/NNNN-short-title.md`, status, context, decision, alternatives, consequences.
- One topic per file; link rather than repeat. No em dashes; one line per paragraph.
