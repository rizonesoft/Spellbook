"""The TODO graph: parse todo/, validate it, and keep the plan projection honest.

A compact port of the Isotone and Resolute todo-graph.py. It keeps their core
contract and drops what Spellbook does not run (the review panel, campaign
guard, budget, backlog ratchets, design lines, and measured claims):

* every TODO file has valid frontmatter in the right domain;
* every `## N.` section has exactly one Implementation Order row and vice versa;
* a row is `[x]` only when a `> **Verified:**` stamp covers it, and then every
  checklist item in the section is ticked (the `Commit:` item excepted);
* every `Depends On` ref and `-> XREF:` resolves, XREFs point both ways, and
  the dependency graph has no cycle;
* a `> **Deferred:**` line names a resolvable owner, and goes stale (FATAL)
  once that owner ships;
* every section sits in exactly one row of todo/implementation-plan.md, no
  earlier than anything it depends on, and the plan's boxes, item counts, and
  Progress line match the tree (`plan --sync` rewrites them);
* every domain INDEX.md lists its TODO files, and skills cite only live refs.

Operator-only work: every section in domain 99 (todo/99-manual/) is work only
the operator does. `query ready` lists such rows as runnable elsewhere, never
as runnable now, and `resolve` exits 5 for one, so an unattended run never
starts it. `--context operator` treats domain 99 as runnable now.

Usage (stdlib only, Python 3.10+):
    python scripts/todo-graph.py validate
    python scripts/todo-graph.py plan --sync | --check
    python scripts/todo-graph.py query ready | blocked | stats [--context operator]
    python scripts/todo-graph.py resolve "D01 T01 §2" [--context operator]
    python scripts/todo-graph.py self-test

Exit codes: 0 ok; 1 findings or a stale plan. `resolve`: 0 open and ready,
2 not found, 3 already shipped, 4 a dependency is unmet, 5 open and ready but
operator-only (domain 99) in the agent context. `query ready` ends with the
line `<N> runnable now, <M> runnable elsewhere`.
"""
from __future__ import annotations

import re
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STATUSES = {"draft", "active", "blocked", "done", "superseded"}
REQUIRED = ("schema_version", "id", "domain", "status", "title")
ID_RE = re.compile(r"^[a-z][a-z0-9-]{1,59}$")
SECTION_RE = re.compile(r"^## (\d+)\. (.+)$")
ROW_RE = re.compile(r"^\|\s*(\d+)\s*\|\s*§(\d+)\s*\|(.*)\|(.*)\|\s*\[( |x)\]\s*\|\s*$")
ITEM_RE = re.compile(r"^\s*- \[( |x)\] (.*)$")
REF_RE = re.compile(r"(?:D(\d{2})\s+)?(?:T(\d{2})\s+)?§(\d+)")
FULL_REF_RE = re.compile(r"D(\d{2}) T(\d{2}) §(\d+)")
VERIFIED_RE = re.compile(r"^> \*\*Verified:\*\* (\d{4}-\d{2}-\d{2}) \| ([^|]+)\|")
DEFERRED_RE = re.compile(r"^> \*\*Deferred:\*\*.*-> XREF: (D\d{2} T\d{2} §\d+)")
XREF_RE = re.compile(r"-> XREF: (D\d{2} T\d{2} §\d+)")
PHASE_RE = re.compile(r"^### Phase (\d+) -- (.+)$")
PLAN_ROW_RE = re.compile(r"^\|\s*\[( |x)\]\s*\|\s*`(D\d{2} T\d{2} §\d+)`\s*\|(.*)\|\s*(\d+)\s*\|\s*$")
PROGRESS_RE = re.compile(r"^> \*\*Progress:\*\*.*$", re.M)
OPERATOR_DOMAIN = "99"
CONTEXTS = ("agent", "operator")


@dataclass
class Section:
    num: int
    title: str
    items: list[tuple[bool, str]] = field(default_factory=list)
    stamped: bool = False
    deferred: list[str] = field(default_factory=list)
    line: int = 0


@dataclass
class Row:
    order: int
    num: int
    deliverable: str
    deps: list[str]
    done: bool
    line: int


@dataclass
class TodoFile:
    path: Path
    rel: str
    domain: str  # "00"
    todo: str  # "01"
    meta: dict[str, str]
    sections: dict[int, Section]
    rows: dict[int, Row]
    xrefs: list[tuple[str, int]]
    text: str

    def ref(self, num: int) -> str:
        return f"D{self.domain} T{self.todo} §{num}"


class Tree:
    def __init__(self, root: Path):
        self.root = root
        self.todo_dir = root / "todo"
        self.files: dict[tuple[str, str], TodoFile] = {}
        self.findings: list[str] = []
        self.domains: dict[str, Path] = {}
        self._load()

    # ---- loading -------------------------------------------------------
    def _load(self) -> None:
        for d in sorted(self.todo_dir.iterdir()) if self.todo_dir.exists() else []:
            m = re.match(r"^(\d{2})-[a-z0-9-]+$", d.name)
            if not (d.is_dir() and m and (d / "INDEX.md").exists()):
                continue
            self.domains[m.group(1)] = d
            for f in sorted(d.glob("TODO-*.md")):
                fm = re.match(r"^TODO-(\d{2})-[a-z0-9-]+\.md$", f.name)
                if not fm:
                    self.fatal(f"{self.rel(f)}:1:file-name:TODO files are named TODO-NN-short-name.md")
                    continue
                tf = self._parse(f, m.group(1), fm.group(1))
                key = (tf.domain, tf.todo)
                if key in self.files:
                    self.fatal(f"{tf.rel}:1:duplicate-number:T{tf.todo} is used twice in domain {tf.domain}")
                self.files[key] = tf

    def rel(self, p: Path) -> str:
        return p.relative_to(self.root).as_posix()

    def fatal(self, msg: str) -> None:
        self.findings.append("FATAL " + msg)

    def _parse(self, path: Path, domain: str, todo: str) -> TodoFile:
        text = path.read_text(encoding="utf-8")
        lines = text.splitlines()
        meta: dict[str, str] = {}
        body_start = 0
        if lines and lines[0].strip() == "---":
            for i in range(1, len(lines)):
                if lines[i].strip() == "---":
                    body_start = i + 1
                    break
                k, _, v = lines[i].partition(":")
                meta[k.strip()] = v.split(" #")[0].strip().strip('"')
        tf = TodoFile(path, self.rel(path), domain, todo, meta, {}, {}, [], text)
        in_order = False
        current: Section | None = None
        for i in range(body_start, len(lines)):
            line = lines[i]
            ln = i + 1
            if line.startswith("## Implementation Order"):
                in_order = True
                current = None
                continue
            m = SECTION_RE.match(line)
            if m:
                in_order = False
                num = int(m.group(1))
                if num in tf.sections:
                    self.fatal(f"{tf.rel}:{ln}:duplicate-section:§{num} appears twice")
                current = Section(num, m.group(2).strip(), line=ln)
                tf.sections[num] = current
                continue
            if line.startswith("## "):
                in_order = False
                current = None
                continue
            if in_order:
                rm = ROW_RE.match(line)
                if rm:
                    deps_cell = rm.group(4).strip()
                    deps = [] if deps_cell in ("--", "") else [d.strip() for d in deps_cell.split(",")]
                    row = Row(int(rm.group(1)), int(rm.group(2)), rm.group(3).strip(), deps, rm.group(5) == "x", ln)
                    if row.num in tf.rows:
                        self.fatal(f"{tf.rel}:{ln}:duplicate-row:§{row.num} has two Implementation Order rows")
                    tf.rows[row.num] = row
                continue
            for xm in XREF_RE.finditer(line):
                tf.xrefs.append((xm.group(1), ln))
            if current is None:
                continue
            im = ITEM_RE.match(line)
            if im:
                current.items.append((im.group(1) == "x", im.group(2)))
            vm = VERIFIED_RE.match(line)
            if vm:
                for a, b in self._ranges(vm.group(2)):
                    if a <= current.num <= b:
                        current.stamped = True
            dm = DEFERRED_RE.match(line)
            if dm:
                current.deferred.append(dm.group(1))
        return tf

    @staticmethod
    def _ranges(cell: str) -> list[tuple[int, int]]:
        out = []
        for part in cell.split(","):
            nums = [int(n) for n in re.findall(r"§(\d+)", part)]
            if len(nums) == 1:
                out.append((nums[0], nums[0]))
            elif len(nums) == 2:
                out.append((nums[0], nums[1]))
        return out

    # ---- refs ----------------------------------------------------------
    def expand(self, ref: str, ctx: TodoFile) -> str | None:
        m = REF_RE.fullmatch(ref.strip())
        if not m:
            return None
        d = m.group(1) or ctx.domain
        t = m.group(2) or ctx.todo
        if m.group(1) and not m.group(2):
            return None  # "D01 §2" is not a form
        return f"D{d} T{t} §{m.group(3)}"

    def lookup(self, full: str) -> tuple[TodoFile, Section] | None:
        m = FULL_REF_RE.fullmatch(full)
        if not m:
            return None
        tf = self.files.get((m.group(1), m.group(2)))
        if not tf:
            return None
        sec = tf.sections.get(int(m.group(3)))
        return (tf, sec) if sec else None

    def all_sections(self):
        for key in sorted(self.files):
            tf = self.files[key]
            for num in sorted(tf.sections):
                yield tf, tf.sections[num]

    def is_done(self, full: str) -> bool:
        hit = self.lookup(full)
        if not hit:
            return False
        tf, sec = hit
        row = tf.rows.get(sec.num)
        return bool(row and row.done)

    def deps_of(self, tf: TodoFile, num: int) -> list[str]:
        row = tf.rows.get(num)
        if not row:
            return []
        out = []
        for d in row.deps:
            full = self.expand(d, tf)
            if full:
                out.append(full)
        return out

    # ---- validation ----------------------------------------------------
    def validate(self) -> list[str]:
        f = self.findings
        if not self.files:
            self.fatal("todo/:1:empty:no TODO files found under todo/NN-domain/")
        ids: dict[str, str] = {}
        for tf in self.files.values():
            for k in REQUIRED:
                if k not in tf.meta:
                    self.fatal(f"{tf.rel}:1:frontmatter:missing '{k}'")
            dom = tf.meta.get("domain", "")
            if dom and dom != tf.path.parent.name:
                self.fatal(f"{tf.rel}:1:frontmatter:domain '{dom}' does not match folder '{tf.path.parent.name}'")
            tid = tf.meta.get("id", "")
            if tid and not ID_RE.match(tid):
                self.fatal(f"{tf.rel}:1:frontmatter:id '{tid}' is not kebab-case a-z0-9-")
            if tid in ids:
                self.fatal(f"{tf.rel}:1:frontmatter:id '{tid}' also used by {ids[tid]}")
            ids[tid] = tf.rel
            st = tf.meta.get("status", "")
            if st and st not in STATUSES:
                self.fatal(f"{tf.rel}:1:frontmatter:status '{st}' is not one of {sorted(STATUSES)}")
            if not tf.sections:
                self.fatal(f"{tf.rel}:1:no-sections:a TODO file has at least one '## N.' section")
            for num, sec in tf.sections.items():
                if num not in tf.rows:
                    self.fatal(f"{tf.rel}:{sec.line}:row-missing:§{num} has no Implementation Order row")
            for num, row in tf.rows.items():
                if num not in tf.sections:
                    self.fatal(f"{tf.rel}:{row.line}:section-missing:row §{num} has no '## {num}.' section")
                    continue
                sec = tf.sections[num]
                if row.done and not sec.stamped:
                    self.fatal(f"{tf.rel}:{row.line}:unstamped-flip:§{num} is [x] without a Verified stamp")
                if sec.stamped and not row.done:
                    self.fatal(f"{tf.rel}:{row.line}:stamp-row-mismatch:§{num} has a Verified stamp but its row is [ ]")
                if row.done:
                    open_items = [t for ok, t in sec.items if not ok and not t.startswith("Commit:")]
                    if open_items:
                        self.fatal(f"{tf.rel}:{row.line}:partial-flip:§{num} is [x] with {len(open_items)} open item(s)")
                if len(sec.items) > 30:
                    f.append(f"WARN {tf.rel}:{sec.line}:section-size:§{num} has {len(sec.items)} items (max 30)")
                for d in row.deps:
                    full = self.expand(d, tf)
                    if not full or not self.lookup(full):
                        self.fatal(f"{tf.rel}:{row.line}:dead-dep:§{num} depends on '{d}', which does not resolve")
            for ref, ln in tf.xrefs:
                hit = self.lookup(ref)
                if not hit:
                    self.fatal(f"{tf.rel}:{ln}:dead-xref:{ref} does not resolve")
                    continue
                target = hit[0]
                if target is tf:
                    continue
                back = any(r.startswith(f"D{tf.domain} T{tf.todo} ") for r, _ in target.xrefs)
                if not back:
                    self.fatal(f"{tf.rel}:{ln}:one-sided-xref:{target.rel} has no -> XREF back to D{tf.domain} T{tf.todo}")
            for num, sec in tf.sections.items():
                for owner in sec.deferred:
                    if not self.lookup(owner):
                        self.fatal(f"{tf.rel}:{sec.line}:dead-deferral:§{num} defers to {owner}, which does not resolve")
                    elif self.is_done(owner):
                        self.fatal(f"{tf.rel}:{sec.line}:stale-deferral:§{num} still says Deferred to {owner}, which has shipped; write Resolved:")
        self._check_cycles()
        self._check_indexes()
        self._check_skills()
        self.findings.extend(self.plan_findings())
        return f

    def _check_cycles(self) -> None:
        state: dict[str, int] = {}

        def visit(full: str, stack: list[str]) -> None:
            if state.get(full) == 2:
                return
            if state.get(full) == 1:
                self.fatal(f"todo/:1:cycle:{' -> '.join(stack + [full])}")
                return
            state[full] = 1
            hit = self.lookup(full)
            if hit:
                for d in self.deps_of(hit[0], hit[1].num):
                    visit(d, stack + [full])
            state[full] = 2

        for tf, sec in self.all_sections():
            visit(tf.ref(sec.num), [])

    def _check_indexes(self) -> None:
        for dom, path in self.domains.items():
            index = (path / "INDEX.md").read_text(encoding="utf-8")
            for (d, _), tf in self.files.items():
                if d == dom and tf.path.name not in index:
                    self.fatal(f"{self.rel(path / 'INDEX.md')}:1:index-missing:{tf.path.name} is not listed")

    def _check_skills(self) -> None:
        for owner in (".claude", ".agents"):
            skills = self.root / owner / "skills"
            for p in sorted(skills.rglob("*.md")):
                for ln, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
                    for m in FULL_REF_RE.finditer(line):
                        if not self.lookup(m.group(0)):
                            self.fatal(f"{self.rel(p)}:{ln}:skill-dead-ref:{m.group(0)} does not resolve")

    # ---- the plan projection -------------------------------------------
    def plan_path(self) -> Path:
        return self.todo_dir / "implementation-plan.md"

    def progress_line(self) -> str:
        total = sum(1 for _ in self.all_sections())
        done = sum(1 for tf, s in self.all_sections() if tf.rows.get(s.num) and tf.rows[s.num].done)
        pct = (100 * done // total) if total else 0
        return (f"> **Progress:** **{done} of {total} sections complete ({pct}%).** Derived from the "
                f"Implementation Order tables by `python scripts/todo-graph.py plan --sync` -- never edited by hand.")

    def synced_plan(self) -> tuple[str, list[str]]:
        """Returns the plan text with boxes, item counts, and Progress re-derived, plus structural findings."""
        path = self.plan_path()
        out_findings: list[str] = []
        if not path.exists():
            return "", ["FATAL todo/implementation-plan.md:1:plan-missing:the plan file does not exist"]
        lines = path.read_text(encoding="utf-8").splitlines()
        seen: dict[str, int] = {}
        phase = -1
        position: dict[str, tuple[int, int]] = {}
        new_lines = []
        for i, line in enumerate(lines):
            pm = PHASE_RE.match(line)
            if pm:
                phase = int(pm.group(1))
            rm = PLAN_ROW_RE.match(line)
            if rm:
                ref = rm.group(2)
                hit = self.lookup(ref)
                if not hit:
                    out_findings.append(f"FATAL todo/implementation-plan.md:{i + 1}:plan-unknown:{ref} is not a section")
                    new_lines.append(line)
                    continue
                if ref in seen:
                    out_findings.append(f"FATAL todo/implementation-plan.md:{i + 1}:plan-duplicate:{ref} also on line {seen[ref]}")
                seen[ref] = i + 1
                position[ref] = (phase, i)
                tf, sec = hit
                box = "x" if self.is_done(ref) else " "
                new_lines.append(f"| [{box}] | `{ref}` | {rm.group(3).strip()} | {len(sec.items)} |")
                continue
            new_lines.append(line)
        for tf, sec in self.all_sections():
            ref = tf.ref(sec.num)
            if ref not in seen:
                out_findings.append(f"FATAL todo/implementation-plan.md:1:plan-missing-row:{ref} ({sec.title}) is in no phase")
        for ref, (ph, idx) in position.items():
            hit = self.lookup(ref)
            for dep in self.deps_of(hit[0], hit[1].num):
                if dep in position and position[dep] > (ph, idx):
                    out_findings.append(f"FATAL todo/implementation-plan.md:{idx + 1}:plan-order:{ref} runs before its dependency {dep}")
        text = "\n".join(new_lines) + "\n"
        text = PROGRESS_RE.sub(lambda _: self.progress_line(), text, count=1)
        if not PROGRESS_RE.search(text):
            out_findings.append("FATAL todo/implementation-plan.md:1:plan-progress:no '> **Progress:**' line")
        return text, out_findings

    def plan_findings(self) -> list[str]:
        text, found = self.synced_plan()
        if text and text != self.plan_path().read_text(encoding="utf-8"):
            found.append("FATAL todo/implementation-plan.md:1:plan-stale:run `python scripts/todo-graph.py plan --sync`")
        return found


# ---- commands ------------------------------------------------------------
def cmd_validate(tree: Tree) -> int:
    findings = tree.validate()
    for f in findings:
        print(f)
    fatal = sum(1 for f in findings if f.startswith("FATAL"))
    warn = len(findings) - fatal
    sections = sum(1 for _ in tree.all_sections())
    print(f"todo-graph validate: {len(tree.files)} files, {sections} sections, {fatal} fatal, {warn} warnings")
    return 1 if fatal else 0


def cmd_plan(tree: Tree, mode: str) -> int:
    text, found = tree.synced_plan()
    for f in found:
        print(f)
    if mode == "--sync":
        if text:
            tree.plan_path().write_text(text, encoding="utf-8", newline="\n")
            print("plan --sync: todo/implementation-plan.md rewritten")
        return 1 if found else 0
    stale = bool(text) and text != tree.plan_path().read_text(encoding="utf-8")
    if stale:
        print("plan --check: STALE; run `python scripts/todo-graph.py plan --sync`")
    elif not found:
        print("plan --check: current")
    return 1 if stale or found else 0


def runnable_here(ref: str, context: str) -> bool:
    """Operator-only work (domain 99) is runnable only in the operator context."""
    return context == "operator" or not ref.startswith(f"D{OPERATOR_DOMAIN} ")


def cmd_query(tree: Tree, what: str, context: str = "agent") -> int:
    rows = []
    for tf, sec in tree.all_sections():
        ref = tf.ref(sec.num)
        if tree.is_done(ref):
            continue
        unmet = [d for d in tree.deps_of(tf, sec.num) if not tree.is_done(d)]
        rows.append((ref, sec.title, unmet))
    if what == "ready":
        ready = [(ref, title) for ref, title, unmet in rows if not unmet]
        now = [r for r in ready if runnable_here(r[0], context)]
        elsewhere = [r for r in ready if not runnable_here(r[0], context)]
        for ref, title in now:
            print(f"{ref}  {title}")
        if elsewhere:
            print("")
            print("runnable elsewhere (operator only, todo/99-manual/):")
            for ref, title in elsewhere:
                print(f"  {ref}  {title}")
        print("")
        print(f"{len(now)} runnable now, {len(elsewhere)} runnable elsewhere")
    elif what == "blocked":
        for ref, title, unmet in rows:
            if unmet:
                print(f"{ref}  {title}  (waits on {', '.join(unmet)})")
    elif what == "stats":
        total = sum(1 for _ in tree.all_sections())
        done = total - len(rows)
        ready = sum(1 for r in rows if not r[2])
        elsewhere = sum(1 for r in rows if not r[2] and not runnable_here(r[0], context))
        print(f"files {len(tree.files)}  sections {total}  done {done}  open {len(rows)}  ready {ready} "
              f"({ready - elsewhere} now, {elsewhere} elsewhere)  blocked {len(rows) - ready}")
    else:
        print(f"unknown query '{what}' (ready | blocked | stats)")
        return 1
    return 0


def cmd_resolve(tree: Tree, arg: str, context: str = "agent") -> int:
    m = FULL_REF_RE.search(arg)
    if not m:
        print(f"resolve: no 'DNN TNN §N' reference in {arg!r}")
        return 2
    ref = m.group(0)
    hit = tree.lookup(ref)
    if not hit:
        print(f"resolve: {ref} not found")
        return 2
    tf, sec = hit
    deps = tree.deps_of(tf, sec.num)
    unmet = [d for d in deps if not tree.is_done(d)]
    print(f"ref      {ref}")
    print(f"file     {tf.rel}")
    print(f"section  §{sec.num}. {sec.title}  (line {sec.line})")
    print(f"items    {len(sec.items)} ({sum(1 for ok, _ in sec.items if ok)} ticked)")
    print(f"deps     {', '.join(deps) or '--'}")
    print(f"unmet    {', '.join(unmet) or '--'}")
    print(f"context  {'operator' if tf.domain == OPERATOR_DOMAIN else 'agent'}")
    if tree.is_done(ref):
        print("status   shipped [x]")
        return 3
    if unmet:
        print("status   blocked")
        return 4
    if not runnable_here(ref, context):
        print("status   ready, operator only (runnable elsewhere)")
        return 5
    print("status   ready")
    return 0


# ---- self-test -----------------------------------------------------------
FIXTURE_TODO = """---
schema_version: 1
id: {id}
domain: {domain}
status: draft
title: "TODO-01 -- Fixture"
---

# TODO-01 -- Fixture

## Inputs

{xref}

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | First       | --         |  [{b1}]   |
|   2   |   §2    | Second      | {dep2}     |  [ ]   |

---

## 1. First

- [{i1}] Do the first thing. Done when: it is done.
- [ ] Commit: `"workspace: first"`

{stamp}

## 2. Second

- [ ] Do the second thing.

## Verification

- [ ] validate clean
"""

FIXTURE_PLAN = """# Plan

> **Progress:** stale

### Phase 0 -- Start

| ✔ | Section | Deliverable | Items |
| :-: | ------- | ----------- | :---: |
{rows}
"""


def _fixture(root: Path, b1=" ", i1=" ", stamp="", dep2="§1", xref=None, plan_rows=None, second=True) -> Tree:
    if xref is None:
        xref = "-> XREF: D01 T01 §1 -- forward" if second else ""
    (root / "todo" / "00-workspace").mkdir(parents=True)
    (root / "todo" / "00-workspace" / "INDEX.md").write_text("TODO-01-fixture.md\n", encoding="utf-8")
    (root / "todo" / "00-workspace" / "TODO-01-fixture.md").write_text(
        FIXTURE_TODO.format(id="fixture-one", domain="00-workspace", b1=b1, i1=i1, stamp=stamp, dep2=dep2, xref=xref),
        encoding="utf-8")
    if second:
        (root / "todo" / "01-library").mkdir(parents=True)
        (root / "todo" / "01-library" / "INDEX.md").write_text("TODO-01-fixture.md\n", encoding="utf-8")
        (root / "todo" / "01-library" / "TODO-01-fixture.md").write_text(
            FIXTURE_TODO.format(id="fixture-two", domain="01-library", b1=" ", i1=" ", stamp="", dep2="§1",
                                xref="-> XREF: D00 T01 §1 -- back"), encoding="utf-8")
    if plan_rows is None:
        plan_rows = ["| [ ] | `D00 T01 §1` | First | 2 |", "| [ ] | `D00 T01 §2` | Second | 1 |"]
        if second:
            plan_rows += ["| [ ] | `D01 T01 §1` | First | 2 |", "| [ ] | `D01 T01 §2` | Second | 1 |"]
    (root / "todo" / "implementation-plan.md").write_text(FIXTURE_PLAN.format(rows="\n".join(plan_rows)), encoding="utf-8")
    tree = Tree(root)
    text, _ = tree.synced_plan()
    tree.plan_path().write_text(text, encoding="utf-8", newline="\n")
    return Tree(root)


def self_test() -> int:
    stamp = "> **Verified:** 2026-10-04 | §1 | build 0"
    cases = [
        ("clean tree", {}, []),
        ("unstamped flip", {"b1": "x", "i1": "x"}, ["unstamped-flip"]),
        ("stamp without flip", {"i1": "x", "stamp": stamp}, ["stamp-row-mismatch"]),
        ("partial flip", {"b1": "x", "stamp": stamp}, ["partial-flip"]),
        ("shipped and stamped", {"b1": "x", "i1": "x", "stamp": stamp}, []),
        ("dead dependency", {"dep2": "§9"}, ["dead-dep"]),
        ("cycle", {"dep2": "§2"}, ["cycle"]),
        ("dead xref", {"xref": "-> XREF: D07 T01 §1 -- nowhere", "second": False}, ["dead-xref"]),
        ("one-sided xref", {"xref": ""}, ["one-sided-xref"]),
        ("missing plan row", {"plan_rows": ["| [ ] | `D00 T01 §1` | First | 2 |"], "second": False}, ["plan-missing-row"]),
        ("plan order", {"plan_rows": ["| [ ] | `D00 T01 §2` | Second | 1 |", "| [ ] | `D00 T01 §1` | First | 2 |"],
                        "second": False}, ["plan-order"]),
        ("stale deferral", {"b1": "x", "i1": "x", "stamp": stamp + "\n> **Deferred:** later -> XREF: D00 T01 §1 (item: \"x\")"},
         ["stale-deferral"]),
    ]
    failed = 0
    for name, kwargs, want in cases:
        with tempfile.TemporaryDirectory() as tmp:
            tree = _fixture(Path(tmp), **kwargs)
            got = sorted({f.split(":")[2] for f in tree.validate() if f.startswith("FATAL")})
            if sorted(want) != got:
                failed += 1
                print(f"self-test '{name}': want {sorted(want)}, got {got}")
                for f in tree.findings:
                    print("   ", f)
    # resolve exit codes
    with tempfile.TemporaryDirectory() as tmp:
        tree = _fixture(Path(tmp))
        import io
        import contextlib
        with contextlib.redirect_stdout(io.StringIO()):
            codes = (cmd_resolve(tree, "D00 T01 §1"), cmd_resolve(tree, "D00 T01 §2"), cmd_resolve(tree, "D09 T01 §1"))
        if codes != (0, 4, 2):
            failed += 1
            print(f"self-test 'resolve exit codes': want (0, 4, 2), got {codes}")
    # operator-only rows: elsewhere in the agent context, now in the operator context
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        _fixture(root, second=False)
        (root / "todo" / "99-manual").mkdir(parents=True)
        (root / "todo" / "99-manual" / "INDEX.md").write_text("TODO-01-fixture.md\n", encoding="utf-8")
        (root / "todo" / "99-manual" / "TODO-01-fixture.md").write_text(
            FIXTURE_TODO.format(id="fixture-op", domain="99-manual", b1=" ", i1=" ", stamp="", dep2="§1", xref=""),
            encoding="utf-8")
        plan = root / "todo" / "implementation-plan.md"
        plan.write_text(plan.read_text(encoding="utf-8").rstrip("\n")
                        + "\n| [ ] | `D99 T01 §1` | First | 2 |\n| [ ] | `D99 T01 §2` | Second | 1 |\n", encoding="utf-8")
        tree = Tree(root)
        import io
        import contextlib
        outs = {}
        for ctx in CONTEXTS:
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                cmd_query(tree, "ready", ctx)
            outs[ctx] = buf.getvalue()
        with contextlib.redirect_stdout(io.StringIO()):
            rcodes = (cmd_resolve(tree, "D99 T01 §1"), cmd_resolve(tree, "D99 T01 §1", "operator"))
        checks = [
            ("an operator row is elsewhere in the agent context",
             "1 runnable now, 1 runnable elsewhere" in outs["agent"] and "  D99 T01 §1" in outs["agent"]),
            ("--context operator makes it runnable now", "2 runnable now, 0 runnable elsewhere" in outs["operator"]),
            ("resolve exits 5, then 0 with --context operator", rcodes == (5, 0)),
        ]
        for name, ok in checks:
            if not ok:
                failed += 1
                print(f"self-test '{name}': failed (outputs {outs}, resolve codes {rcodes})")
    # Both independently owned skill trees are checked without importing either.
    for owner in (".claude", ".agents"):
        for ref, expected in (("D00 T01 §1", False), ("D00 T01 §99", True)):
            with tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                _fixture(root)
                skill = root / owner / "skills" / "probe" / "SKILL.md"
                skill.parent.mkdir(parents=True)
                skill.write_text(ref + "\n", encoding="utf-8")
                got = any("skill-dead-ref" in finding for finding in Tree(root).validate())
                if got != expected:
                    failed += 1
                    print(f"self-test '{owner} skill ref {ref}': expected dead={expected}, got {got}")
    total = len(cases) + 1 + 3 + 4
    print(f"todo-graph self-test: {total - failed} passed, {failed} failed")
    return 1 if failed else 0


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 1
    context = "agent"
    if "--context" in argv:
        i = argv.index("--context")
        if i + 1 >= len(argv) or argv[i + 1] not in CONTEXTS:
            print(f"--context takes one of: {', '.join(CONTEXTS)}")
            return 1
        context = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    cmd = argv[0]
    if cmd == "self-test":
        return self_test()
    tree = Tree(ROOT)
    if cmd == "validate":
        return cmd_validate(tree)
    if cmd == "plan" and len(argv) > 1 and argv[1] in ("--sync", "--check"):
        return cmd_plan(tree, argv[1])
    if cmd == "query" and len(argv) > 1:
        return cmd_query(tree, argv[1], context)
    if cmd == "resolve" and len(argv) > 1:
        return cmd_resolve(tree, " ".join(argv[1:]), context)
    print(__doc__)
    return 1


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main(sys.argv[1:]))
