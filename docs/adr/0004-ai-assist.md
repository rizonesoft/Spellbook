# ADR 0004: AI Assist Through OpenRouter and ACP Agents

- **Status:** Accepted (the default chat model is recorded by `D06 T01 §3` when it runs)
- **Date:** 2026-10-04
- **Deciders:** the operator, in session on 2026-10-04 (answers quoted below)

## Context

The operator asked: "there should also be AI features for writing and refining prompts and other intelligent features. For this we can use https://agentclientprotocol.com/get-started/agents and OpenRouter API." ADR 0003 had made the update check the app's only network call; this record adds the AI features, their providers, and the rules that keep them trustworthy.

## Decisions

### The features, all in v0.1.0

Refine a spell (with a reviewable diff), Write from a description, Rune-ify, Critique, Auto title and tags (title, description, sigils, target model), Semantic search, and Adapt for a model. Test run was offered and not chosen (backlog `B-010`). "v0.1.0": AI ships in the premium first release, opt in and off until a provider is set up.

### Two providers, either for any feature

"Either provider, any feature". **OpenRouter** (an API key, any model, OpenAI-compatible chat completions with streaming) and **ACP agents** the user already runs (Spellbook is an Agent Client Protocol client: it launches the agent as a subprocess and speaks JSON-RPC over stdio). Settings picks the default provider; any AI command can run with the other.

### Semantic search embeds through OpenRouter

ACP agents only chat, so "OpenRouter embeddings": `POST /api/v1/embeddings` with a small embedding model (default `openai/text-embedding-3-small` at 512 dimensions). Vectors are stored locally in the database and searched in core.

### The key lives in Windows Credential Manager

"Windows Credential Manager": the OpenRouter key is a generic credential per user and per data folder, never written to Spellbook's files, logs, or UI after entry.

### Privacy is configurable on the Privacy page

"Should be configurable in a Privacy Settings page". The defaults are the conservative ones: text is sent only when the user runs an AI command, a confirmation shows the provider, the model, and the exact text first, background suggestions are off, and the semantic index is off until turned on. Each switch has a one-sentence plain explanation; `docs/user/privacy.md` lists, per feature, what is sent where.

### Costs are shown, with a monthly cap

"Show cost, monthly cap": every OpenRouter result shows its cost; a monthly cap (default USD 5) refuses further calls once reached. ACP agents bill under the user's own agent account, which Spellbook cannot see, and the UI says so.

### The ACP client is text-only

Spellbook declares no file-system and no terminal capability, runs each request in a fresh session inside an empty private folder, refuses every permission request, and kills the agent with a Job object when it exits. An agent can produce text for Spellbook and nothing else through it.

### The default chat model

Model slugs change faster than plans. `D06 T01 §3` chooses a capable general model from OpenRouter's live model list on the day it runs and records it here with the date:

- *To be recorded by `D06 T01 §3`.*

## Consequences

- Network traffic now has two sources: the update check and the AI features; both are governed by the Privacy page.
- A new domain, `todo/06-ai/`, and a milestone, M6, before the release.
- No unattended test spends money: every AI feature is proven against a local mock OpenRouter server and a mock ACP agent; the live trial is the operator's (`D99 T01 §11`).
- There is no C++ ACP SDK, so the client is Spellbook's own code in core, tested with recorded transcripts.
