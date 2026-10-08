# Codex Run Records

Codex campaigns write `<run_id>.md` here using the supervisor's UUID. Record Phase repairs, Shipped-row verification, Gap audit, Sections, Critical events, and Lessons. Intermediate phases use `### Phase N closeout` or `### Phase N parked`. Final `## Closeout` or column-zero `PARKED <UTC stamp> <reason>` ends only a campaign whose scoped graph has no runnable rows. See [the Codex runbook](../dev/codex.md).

This directory is independent of other agents' records. Runtime ownership, pause markers, and raw logs stay under ignored `build/codex/`.
