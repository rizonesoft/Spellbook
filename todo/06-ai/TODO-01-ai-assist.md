---
schema_version: 1
id: ai-assist
domain: 06-ai
status: draft
title: "TODO-01 -- AI Assist: OpenRouter and ACP Agents for Writing, Refining, and Finding Spells"
depends_on: []
---

# TODO-01 -- AI Assist: OpenRouter and ACP Agents for Writing, Refining, and Finding Spells

> **Goal:** Spellbook helps write better prompts. Through a provider the user chooses, either OpenRouter (an API key, any model) or an ACP agent they already use (Claude, Gemini CLI, Codex, and others from the ACP registry), it refines a spell with a reviewable diff, adapts one for a target model, writes a new spell from a one-line description, turns the changing parts of a spell into runes without losing a word, critiques a spell with a score and concrete fixes, suggests a title, description, sigils, and target model, and finds spells by meaning. Nothing leaves the PC except as the Privacy page allows, every OpenRouter result shows its cost, and a monthly cap stops spending.

> [!IMPORTANT]
> **Current state (verified 2026-10-04):** Nothing here exists. Operator decisions 2026-10-04, after "there should also be AI features for writing and refining prompts and other intelligent features. For this we can use https://agentclientprotocol.com/get-started/agents and OpenRouter API" (ADR 0004): features Refine, Write from a description, Rune-ify, Critique, Auto title and tags, Semantic search, Adapt for a model (Test run was offered and not chosen); **either provider for any feature**, with a default in Settings; semantic search embeds through **OpenRouter's embeddings endpoint** (ACP agents cannot embed); the OpenRouter key lives in **Windows Credential Manager**; what is sent and when is **configurable on the Privacy page** (defaults: only on an explicit action, with a confirmation showing the exact text; background suggestions and the semantic index off); OpenRouter costs are **shown with a monthly cap** (default USD 5). All of it ships in v0.1.0, opt in, off until a provider is set up. OpenRouter: `POST https://openrouter.ai/api/v1/chat/completions` (OpenAI-compatible, `stream: true` gives Server-Sent Events), `POST /api/v1/embeddings`, `GET /api/v1/models`, `Authorization: Bearer <key>`, optional `HTTP-Referer` and `X-Title` attribution headers. ACP: JSON-RPC 2.0 over stdio, newline-delimited, the client (Spellbook) launches the agent as a subprocess; `initialize`, optional `authenticate`, `session/new`, `session/prompt`, `session/update` notifications, `session/cancel`; clients must answer `session/request_permission`; the registry is `https://cdn.agentclientprotocol.com/registry/v1/latest/registry.json`. There is no C++ ACP SDK: the client is written in core. Model slugs change often: the default chat model is chosen by §3 from the live model list on the day it runs and recorded in ADR 0004 with the date.

## Inputs

- Agent Client Protocol: `https://agentclientprotocol.com/protocol/overview`, `/protocol/v1/initialization`, `/protocol/v1/transports`, `/get-started/registry` -- read in full before §4
- OpenRouter API reference: chat completions (streaming, `usage`), embeddings, models, errors, authentication
- Microsoft Learn: Credential Manager (`CredWriteW`, `CredReadW`, `CredDeleteW`), WinHTTP, `CreateProcessW` with redirected handles, Job objects (`JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`)
- -> XREF: D05 T03 §4 -- the Privacy page and the update client's WinHTTP code this file extends
- -> XREF: D05 T01 §2 -- the settings store for provider, models, privacy, and the cap
- -> XREF: D04 T01 §6 -- the line diff the Refine review uses
- -> XREF: D04 T02 §1 -- the rune syntax Rune-ify must produce
- -> XREF: D01 T02 §6 -- tabs, where Write from a description opens its draft
- -> XREF: D03 T01 §4 -- the search box semantic search joins
- -> XREF: D03 T02 §2 -- the capture flyout that offers suggestions
- -> XREF: D99 T01 §11 -- the operator's live trial with a real key and a real agent

## Outcome

- Settings > AI configures OpenRouter (key, chat model, embedding model) and ACP agents (from the registry or a custom command), and picks the default provider; Settings > Privacy holds every sharing control.
- Refine, Adapt, Write, Rune-ify, Critique, and Suggest run through either provider, stream their output, can be cancelled, and never change a spell without the user accepting.
- Rune-ify is lossless: its result rendered with its own defaults equals the original text, or it is refused.
- Semantic search ranks spells by meaning, blended with full-text search, from vectors stored locally.
- Every feature is proven unattended against a local mock OpenRouter server and a mock ACP agent; no test spends money.

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | The AI core: requests, feature prompts, parsers, and the spend ledger | D04 T02 §1 |  [ ]   |
|   2   |   §2    | Credentials, AI settings, and the privacy controls | §1, D05 T03 §4 |  [ ]   |
|   3   |   §3    | The OpenRouter client and its mock server | §2 |  [ ]   |
|   4   |   §4    | The ACP client, the registry, and a mock agent | §2 |  [ ]   |
|   5   |   §5    | Refine and Adapt: suggestions reviewed as a diff | §3, §4, D04 T01 §6 |  [ ]   |
|   6   |   §6    | Write from a description and Rune-ify | §5, D01 T02 §6 |  [ ]   |
|   7   |   §7    | Critique | §5 |  [ ]   |
|   8   |   §8    | Suggest title, description, sigils, and model | §5, D03 T02 §2 |  [ ]   |
|   9   |   §9    | Semantic search | §3, D03 T01 §4 |  [ ]   |
|  10   |   §10   | The AI guide and the privacy page | §6, §7, §8, §9 |  [ ]   |

---

## 1. The AI Core: Requests, Feature Prompts, Parsers, and the Spend Ledger

Everything an AI feature decides (what to send, how to read the answer, whether the answer is safe to apply, whether the budget allows the call) is pure logic and lives in core, tested without a network.

- [ ] `src/core/include/spellbook/core/ai/request.hpp`: a provider-neutral `AiRequest` (feature, system text, user text, model, max output tokens, temperature, `expects_json`) and `AiResult` (text, usage with prompt and completion tokens and cost in USD when known, provider, model, elapsed ms). Done when: it compiles in core with no Windows or network header.
- [ ] Feature prompts as Markdown files in `src/core/ai/prompts/` (`refine.v1.md`, `adapt.v1.md`, `write.v1.md`, `runeify.v1.md`, `critique.v1.md`, `suggest.v1.md`), embedded at build time like migrations (`cmake/EmbedMigrations.cmake` pattern), each stating the rune syntax of `D04 T02 §1` where relevant and the exact output shape; `build_<feature>_request(...)` functions fill them. Done when: tests assert each request's text for a fixed spell (golden files in `tests/fixtures/ai/requests/`).
- [ ] Parsers: plain-text outputs strip one surrounding code fence and leading "Here is" chatter; JSON outputs take the first JSON object in the text (fenced or not) and validate it: Critique `{score 0-10, summary, items[{severity: high|medium|low, issue, suggestion}]}`, Rune-ify `{template, runes[{name, default}]}`, Suggest `{title, description, sigils[], target_model}`. Rune-ify is accepted only if `render(parse_template(template), defaults)` equals the original text after line-ending normalisation. Done when: tests over recorded model outputs in `tests/fixtures/ai/responses/` (good, chatty, fenced, truncated, invalid JSON, lossy Rune-ify) pass, each bad one rejected with a reason.
- [ ] `SpendLedger`: records cost per call with a UTC timestamp, totals the current calendar month, and refuses a call when the month's total has reached the cap. Done when: fake-clock tests cover the month boundary and a cap of 0 (refuses everything).
- [ ] Commit: `"core: the AI request model, feature prompts, parsers, and spend ledger (D06 T01 §1)"`

**Test checkpoint:** Unit test: `pwsh scripts/test.ps1 -Filter "core: .*ai"` passes; a mutant that skips the Rune-ify losslessness check fails the lossy fixture.

## 2. Credentials, AI Settings, and the Privacy Controls

- [ ] `src/app/credentials.cpp`: the OpenRouter key stored with `CredWriteW` as a generic credential, target `Spellbook/OpenRouter/<instance key>` (the data-folder hash of `D01 T02 §1`, so a portable copy has its own), read with `CredReadW`, removed with `CredDeleteW`; the key never appears in settings, logs, crash dumps' log lines, or the UI after entry (shown as `sk-or-...` plus the last 4). Done when: a test hook writes, reads, and deletes a dummy key, and `grep` over the data folder after a driven run finds no key text.
- [ ] Settings (core `Settings`, `D05 T01 §2`): `ai.default_provider` (`none`, `openrouter`, or an agent id; default `none`), `ai.openrouter.chat_model`, `ai.openrouter.embedding_model` (default `openai/text-embedding-3-small` at 512 dimensions), `ai.agents[]` (id, name, command, args, env), `ai.monthly_cap_usd` (default 5.00), `privacy.ai_send` (`explicit` default, or `background_allowed`), `privacy.ai_confirm_before_send` (default true), `privacy.semantic_index` (default false). Done when: core tests cover defaults and round trip.
- [ ] Settings dialog pages: AI (provider, key entry with Test connection, models, agents list) and the Privacy page from `D05 T03 §4` gains the three AI switches, each with one plain sentence of what it means. AutomationIds `settings-ai`, `ai-provider`, `ai-key`, `ai-test`, `privacy-ai-send`, `privacy-ai-confirm`, `privacy-semantic-index`. Done when: each control persists and is read by its consumer.
- [ ] Commit: `"app: AI settings, the key in Credential Manager, and privacy controls (D06 T01 §2)"`

**Test checkpoint:** Unit test plus driven run with evidence: the settings tests pass; `tests/ui/scenarios/ai-settings.ps1` enters a dummy key, restarts, sees the masked key, removes it, and asserts no key text anywhere under the data folder.

## 3. The OpenRouter Client and Its Mock Server

- [ ] `src/core/include/spellbook/core/ai/sse.hpp`: an incremental Server-Sent Events parser (partial lines across reads, `data:` lines, `: comment` keep-alives such as `: OPENROUTER PROCESSING`, `data: [DONE]`) and OpenAI-compatible chunk parsing (`choices[0].delta.content`, final `usage` with `cost`). Done when: tests feed recorded streams split at every byte boundary and get the same text.
- [ ] `src/app/openrouter_client.cpp` on WinHTTP: chat completions with `stream: true` and `usage: {"include": true}`, embeddings, and the model list (cached for 24 h); headers `Authorization`, `Content-Type`, `HTTP-Referer: https://github.com/rizonesoft/Spellbook`, `X-Title: Spellbook`; connect timeout 10 s, idle timeout 60 s; cancellation closes the request. Errors map to plain messages: 401 (key rejected), 402 (no credit), 429 (rate limited, honouring `Retry-After`), 5xx and network failures. The base URL comes from `ai.openrouter.base_url` (default `https://openrouter.ai/api/v1`) for tests. Done when: each error is shown by a driven run against the mock.
- [ ] The default chat model: query the live model list on the day this section runs, choose a capable general model available to all accounts, record its slug and the date in `docs/adr/0004-ai-assist.md`, and make it the setting's default. Done when: the ADR names it.
- [ ] `tests/ai/mock_openrouter.py` (stdlib `http.server`): streams scripted chat responses from `tests/fixtures/ai/streams/`, returns embeddings deterministically from a hash of the input, serves a model list, can be told to fail with 401, 402, 429, or a dropped connection, and logs every request (headers redacted except names) to a file the scenarios assert on. Done when: `python tests/ai/mock_openrouter.py --self-test` passes.
- [ ] Commit: `"core, app: the OpenRouter client with streaming, and its mock (D06 T01 §3)"`

**Test checkpoint:** Unit test plus driven run with evidence: the SSE tests pass; `tests/ui/scenarios/openrouter-client.ps1` runs Test connection against the mock for success and each failure, asserting the message shown and the request headers logged.

## 4. The ACP Client, the Registry, and a Mock Agent

Spellbook is an ACP client that uses an agent only to produce text. It declares no file-system or terminal capability, runs each request in a new session inside an empty private folder, and refuses every permission request, so an agent can never touch the user's files through Spellbook.

- [ ] `src/core/include/spellbook/core/acp/connection.hpp`: a transport-agnostic JSON-RPC 2.0 state machine (request ids, pending requests, notifications, errors) and the ACP v1 client flow: `initialize` (the protocol version from the spec's initialization page, `clientCapabilities` with `fs.readTextFile` and `fs.writeTextFile` false and `terminal` false, `clientInfo` name and version), `authenticate` when the agent requires it and offers a method, `session/new` (cwd, no MCP servers), `session/prompt` with one text content block, collecting `session/update` `agent_message_chunk` text until the prompt's stop reason, answering `session/request_permission` with a cancelled outcome, and `session/cancel`. Done when: tests drive it with scripted transcripts in `tests/fixtures/acp/` (happy path, auth required, permission request, cancel, agent error, malformed line).
- [ ] `src/app/acp_process.cpp`: launches the agent with `CreateProcessW` (stdin and stdout pipes, stderr to the debug log), inside a Job object that kills it when Spellbook exits, a newline-delimited reader thread, a 120 s overall timeout, and a per-run private empty folder under `<data>\ai\sessions\` deleted afterwards. Done when: killing Spellbook mid-request leaves no agent process (checked by the scenario).
- [ ] The agent list: Settings > AI > Add agent fetches the registry on demand (an explicit action), shows entries whose distribution can run here (`npx` or `uvx` found on PATH) with name, description, and command, and allows a custom agent (command, arguments, environment). Done when: the registry fixture in `tests/fixtures/acp/registry.json` lists correctly with and without `npx` on PATH.
- [ ] `tests/ai/mock_acp_agent.py` (stdlib, ACP over stdio): answers `initialize`, optional auth, sessions, and prompts from scripted replies, can send a permission request, and logs every message. Done when: `python tests/ai/mock_acp_agent.py --self-test` passes.
- [ ] Commit: `"core, app: the ACP client, agent registry, and mock agent (D06 T01 §4)"`

**Test checkpoint:** Unit test plus driven run with evidence: the ACP tests pass; `tests/ui/scenarios/acp-client.ps1` adds the mock as a custom agent, runs Test connection, asserts the transcript shows `initialize` with both capabilities false and a refused permission request, and that no `python` mock process survives a forced exit.

## 5. Refine and Adapt: Suggestions Reviewed as a Diff

**Job:** the user can improve a spell, or retarget it to a model, without losing control of the text.
**Treatment:** the editor gains an AI button (sparkle) and an AI menu: Refine, Adapt for (Claude, ChatGPT, Gemini, Copilot, a local model, or the spell's target model). When `privacy.ai_confirm_before_send` is on, a confirmation shows the provider, the model, the exact text to be sent, and (for OpenRouter) the month's spend against the cap. The suggestion streams into a review pane beside the original, shown as a line diff when complete, with Accept (replaces the body through the normal save, so a revision is written), Edit (accept into the editor without saving yet), and Discard; Cancel stops a running request. The result shows the provider, the time taken, and the cost. Cheaper substitute that fails the checkpoint: replacing the body directly with the model's output.
**Chrome:** consume the request builders of §1, the providers of §3 and §4 behind one `IAiProvider` interface in the app, the diff of `D04 T01 §6`, the spend ledger, and the vocabulary table. Do not write to the database before Accept.

- [ ] `IAiProvider` with the OpenRouter and ACP implementations; the provider is the setting's default unless the menu's "Run with" submenu picks another. Done when: both run the same feature.
- [ ] Refine and Adapt with the confirmation, streaming review, diff, Accept, Edit, Discard, Cancel, cost line, and the cap refusal (an InfoBar naming the cap and a link to Settings). AutomationIds `ai-button`, `ai-refine`, `ai-adapt`, `ai-confirm-send`, `ai-review`, `ai-accept`, `ai-edit`, `ai-discard`, `ai-cancel`. Done when: every control works against both mocks.
- [ ] `tests/ui/scenarios/ai-refine.ps1`: refine through the OpenRouter mock and accept (assert a new revision and the body via `dbread.py`), adapt through the ACP mock and discard (assert nothing changed), cancel mid-stream, hit the cap with a ledger seeded to 5.00 (assert no request reached the mock). Done when: it exits 0.
- [ ] Commit: `"app: Refine and Adapt with a reviewable diff (D06 T01 §5)"`

**Test checkpoint:** Driven run with evidence: `pwsh scripts/drive.ps1 -Scenario ai-refine` exits 0; captures of the confirmation and the review under `docs/captures/ai-refine/`; the mock logs quoted.

## 6. Write from a Description and Rune-ify

**Job:** the user can start a spell from an idea, and turn a one-off prompt into a reusable template.
**Treatment:** New spell with AI (Ctrl+Shift+I) asks for one sentence and an optional target model and chapter, streams a complete draft (with runes where they help) into a new tab marked "Draft", and creates the spell only on Keep. Rune-ify on an open spell proposes a template with its runes highlighted and their defaults listed; the proposal is applied only if lossless (§1), otherwise the user sees "The suggestion changed your text, so it was not applied" with Retry. Cheaper substitute that fails the checkpoint: inserting a draft into the current spell.
**Chrome:** consume §5's provider, confirmation, streaming, and cost plumbing, the tabs of `D01 T02 §6`, and the smart editor's highlighting. Do not create a spell before Keep.

- [ ] Write from a description and Rune-ify with AutomationIds `ai-write`, `ai-write-description`, `ai-keep`, `ai-runeify`, `ai-runeify-apply`. Done when: both work against both mocks.
- [ ] `tests/ui/scenarios/ai-write-runeify.ps1`: write a spell and keep it (assert it exists with the drafted body), rune-ify with a lossless fixture (applied) and a lossy fixture (refused, body unchanged). Done when: it exits 0.
- [ ] Commit: `"app: write from a description and Rune-ify (D06 T01 §6)"`

**Test checkpoint:** Driven run with evidence: `pwsh scripts/drive.ps1 -Scenario ai-write-runeify` exits 0.

## 7. Critique

**Job:** the user can learn how to make a spell better before using it.
**Treatment:** Critique opens a side panel: a score out of 10, a one-line summary, and findings grouped by severity, each with the issue and a concrete suggestion; "Refine with these suggestions" runs §5's Refine with the findings appended to the instruction. The last critique per spell is kept for the session. Cheaper substitute that fails the checkpoint: a free-text answer in a message box.
**Chrome:** consume the Critique parser of §1 and §5's plumbing. Do not store critiques in the database.

- [ ] The Critique panel (AutomationIds `ai-critique`, `critique-score`, `critique-items`, `critique-refine`). Done when: it works against both mocks and refuses an invalid JSON reply with a retry.
- [ ] `tests/ui/scenarios/ai-critique.ps1`. Done when: it exits 0.
- [ ] Commit: `"app: Critique (D06 T01 §7)"`

**Test checkpoint:** Driven run with evidence: `pwsh scripts/drive.ps1 -Scenario ai-critique` exits 0; a capture under `docs/captures/ai-critique/`.

## 8. Suggest Title, Description, Sigils, and Model

**Job:** the user can file new and captured spells without typing their metadata.
**Treatment:** a Suggest button in the Details panel and the capture flyout fills title, description, sigils (existing sigils preferred, new ones marked), and target model as suggestions the user accepts per field or all at once. When `privacy.ai_send` is `background_allowed`, new and captured spells get suggestions automatically (shown, never applied, until accepted). Cheaper substitute that fails the checkpoint: overwriting the fields.
**Chrome:** consume the Suggest parser of §1, §5's plumbing, the Details panel of `D01 T02 §5`, and the capture flyout of `D03 T02 §2`. Do not apply a suggestion without a click.

- [ ] Suggest in both places with per-field accept (AutomationIds `ai-suggest`, `suggest-accept-all`, `suggest-accept-<field>`); background mode respects the Privacy setting. Done when: with the setting at `explicit`, the mock records no request until Suggest is clicked.
- [ ] `tests/ui/scenarios/ai-suggest.ps1`. Done when: it exits 0.
- [ ] Commit: `"app: suggested title, description, sigils, and model (D06 T01 §8)"`

**Test checkpoint:** Driven run with evidence: `pwsh scripts/drive.ps1 -Scenario ai-suggest` exits 0; the mock's request log proves the privacy rule both ways.

## 9. Semantic Search

**Job:** the user can find a spell by what it does, not the words it uses.
**Treatment:** when `privacy.semantic_index` is turned on, Spellbook shows the spell count, the estimated cost, and the model, then embeds every spell in batches through OpenRouter (progress in the status bar, cancellable), and re-embeds a spell 30 s after it changes; the search box gains a Meaning toggle that blends semantic and full-text ranks (reciprocal rank fusion). Turning the index off deletes the stored vectors. Cheaper substitute that fails the checkpoint: sending the query to a model and asking it to pick spells.
**Chrome:** consume the embeddings client of §3, the search box of `D03 T01 §4`, and the spend ledger. Do not send a spell's text when the index is off.

- [ ] The next free migration (`migrations/NNNN_embeddings.sql`): `prompt_embeddings(prompt_id PRIMARY KEY REFERENCES prompts ON DELETE CASCADE, model TEXT, dims INTEGER, content_hash TEXT, vector BLOB)`. Done when: an upgraded fixture keeps every prompt.
- [ ] Core: `cosine_top_k(query, vectors, k)` over float32 vectors and `fuse_ranks(fts_hits, semantic_hits)`; 10,000 vectors of 512 dimensions searched in under 30 ms in Release. Done when: unit and perf tests pass.
- [ ] The indexer and the Meaning toggle (AutomationIds `search-meaning`, `privacy-semantic-index`). Done when: against the mock, a query shares no words with its best match and still finds it (the mock's deterministic embeddings are scripted for this pair).
- [ ] `tests/ui/scenarios/semantic-search.ps1`: enable, index 50 seeded spells, search by meaning, edit a spell and wait for re-embedding, disable and assert the table is empty. Done when: it exits 0.
- [ ] Commit: `"storage, core, app: semantic search (D06 T01 §9)"`

**Test checkpoint:** Unit test plus driven run with evidence: the perf test passes and `pwsh scripts/drive.ps1 -Scenario semantic-search` exits 0.

## 10. The AI Guide and the Privacy Page

- [ ] `docs/user/ai.md`: setting up OpenRouter (key, models, cap) and ACP agents (registry, custom), each feature with captures, costs, and what to do when a provider fails; `docs/user/privacy.md` fills its AI section: for each feature, exactly what text is sent to which provider, and that ACP agents run as the user's own programs under their own terms. Done when: linked from `docs/user/README.md` and the README.
- [ ] `docs/adr/0004-ai-assist.md` complete (decisions, the default model and its date, the security posture of the ACP client). Done when: Status Accepted.
- [ ] `CHANGELOG.md` Unreleased lists the AI features. Done when: present.
- [ ] Commit: `"docs: AI assist and privacy (D06 T01 §10)"`

**Test checkpoint:** Static evidence: `python scripts/check-docs.py` prints `0 findings`.

## Verification

- [ ] `pwsh scripts/check-all.ps1` exits 0
- [ ] Every `ai-*`, `acp-client`, `openrouter-client`, and `semantic-search` scenario exits 0 against the mocks
- [ ] No test or scenario sends a request to a real provider (the scenarios assert the base URLs point at the mocks)
- [ ] `python scripts/todo-graph.py validate` clean
