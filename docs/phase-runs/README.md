# Phase Runs

One file per `process-phase` run: `<YYYY-MM-DD>-phase-<N>.md`. The run appends every finding the moment it is made, so the file survives a session that dies, and it is what the operator reads during and after an unattended run.

Each file has these sections: Phase repairs, Shipped-row verification, Gap audit, Sections (one entry per shipped section: ref, commit, push, review verdict, corrections), Critical events (every stop, pause, resume, session death, and guard write), and Lessons.

A run ends in exactly one of two written ways, and the Stop hook (`.claude/hooks/campaign-stop.ps1`) reads only these shapes:

- **Closeout:** a line `## Closeout` followed by what shipped, what was repaired, and what was learned.
- **Park:** a column-0 line `PARKED <UTC stamp> <one-line reason>` followed by the park record: each leftover row, what blocks it, and for operator-only rows (`todo/99-manual/`) the exact step the operator must take.

The skills that write these files are `process-plan` and `process-phase` under `.claude/skills/`.
