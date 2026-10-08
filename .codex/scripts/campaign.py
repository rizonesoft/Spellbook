"""Codex-only campaign control. Stdlib; never imports another agent's runtime."""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
NO_WINDOW = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0


def run(root: Path, args: list[str]) -> str:
    return subprocess.check_output(args, cwd=root, text=True, encoding="utf-8",
                                   errors="strict", stderr=subprocess.PIPE,
                                   creationflags=NO_WINDOW, timeout=60)


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + "." + uuid.uuid4().hex + ".tmp")
    tmp.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def state_path(root: Path) -> Path:
    return root / "build/codex/campaign.json"


def owned(root: Path, state: dict) -> bool:
    return state.get("runner") == "codex" and Path(state.get("workspace", "")).resolve() == root.resolve()


def run_dir(root: Path, state: dict) -> Path:
    return root / "build/codex/runs" / str(uuid.UUID(state["run_id"]))


def paused(root: Path, state: dict) -> bool:
    return (run_dir(root, state) / "pause.json").exists()


def pause(root: Path, state: dict, reason: str) -> None:
    if not owned(root, state):
        raise ValueError("campaign belongs to another workspace or runner")
    write(run_dir(root, state) / "pause.json", {"reason": reason, "time": time.time()})


@contextlib.contextmanager
def lock(root: Path, name: str = "supervisor.lock"):
    """An OS lock is released on process death; never steal a PID-based lock."""
    path = root / "build/codex" / name
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a+b") as stream:
        stream.seek(0)
        if not stream.read(1):
            stream.write(b"0")
            stream.flush()
        stream.seek(0)
        if os.name == "nt":
            import msvcrt
            msvcrt.locking(stream.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        try:
            yield
        finally:
            stream.seek(0)
            if os.name == "nt":
                msvcrt.locking(stream.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                fcntl.flock(stream, fcntl.LOCK_UN)


def graph(root: Path, *args: str) -> str:
    return run(root, [sys.executable, "scripts/todo-graph.py", *args])


def ready(root: Path, phase: int | None = None) -> list[str]:
    output = graph(root, "query", "ready")
    summary = re.search(r"^(\d+) runnable now, \d+ runnable elsewhere\s*$", output, re.M)
    if not summary:
        raise ValueError("TODO readiness output has no valid summary")
    refs = re.findall(r"^(D\d{2} T\d{2} §\d+)\b", output, re.M)
    if len(refs) != int(summary[1]) or any(ref.startswith("D99 ") for ref in refs):
        raise ValueError("TODO readiness output is inconsistent or includes operator work")
    if phase is None:
        return refs
    text = (root / "todo/implementation-plan.md").read_text(encoding="utf-8")
    sections = re.split(r"^### Phase (\d+) -- .*\n", text, flags=re.M)
    for number, body in zip(sections[1::2], sections[2::2]):
        if int(number) == phase:
            return [ref for ref in refs if f"`{ref}`" in body]
    raise ValueError(f"Phase {phase} is absent from the plan")


def fingerprint(root: Path) -> str:
    """Hash actual content, including new files; log chatter is not progress."""
    digest = hashlib.sha256()
    files = run(root, ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"])
    for name in sorted(set(files.split("\0")) - {""}):
        if name.startswith("docs/codex-runs/"):
            continue
        path = root / name
        digest.update(name.encode())
        digest.update(path.read_bytes() if path.is_file() else b"<absent>")
    return digest.hexdigest()


def record_path(root: Path, state: dict) -> Path:
    expected = Path("docs/codex-runs") / (state["run_id"] + ".md")
    if state.get("run_file") != expected.as_posix():
        raise ValueError("invalid Codex run record path")
    path = (root / expected).resolve()
    if not path.is_relative_to((root / "docs/codex-runs").resolve()):
        raise ValueError("run record escaped its directory")
    return path


def decision(root: Path, state: dict) -> tuple[bool, str]:
    if not owned(root, state):
        raise ValueError("campaign belongs to another workspace or runner")
    if paused(root, state) or state.get("status") != "running":
        return False, "paused or inactive"
    text = record_path(root, state).read_text(encoding="utf-8")
    candidates = ready(root, state.get("phase"))
    # A closeout must agree with the graph. An invented marker cannot finish work.
    if not candidates and re.search(r"^(## Closeout|PARKED\b)", text, re.M):
        return False, "closeout or park with no runnable work in scope"
    return True, ("Continue with " + candidates[0] if candidates else
                  "No runnable work remains: record the closeout or blocked/operator-only park")


def hook(root: Path, event: dict) -> dict:
    path = state_path(root)
    if not path.exists():
        return {}
    state = read(path)
    if not owned(root, state) or not state.get("session_id") or state["session_id"] != event.get("session_id"):
        return {}
    if event.get("hook_event_name") == "Interrupt":
        pause(root, state, "operator interrupted Codex")
        return {}
    if event.get("hook_event_name") != "Stop":
        return {}
    again, reason = decision(root, state)
    if not again:
        return {}
    path = run_dir(root, state) / "stop-state.json"
    previous = read(path) if path.exists() else {}
    current = fingerprint(root)
    blocks = previous.get("blocks", 0) if previous.get("fingerprint") == current else 0
    if blocks >= 3:
        pause(root, state, "three Stop continuations without repository progress")
        return {"systemMessage": "Codex campaign paused after three continuations without progress."}
    write(path, {"fingerprint": current, "blocks": blocks + 1})
    return {"decision": "block", "reason": reason + ". Follow .agents/skills/process-plan/SKILL.md; independent review before stamping; honor pause.json and operator stops."}


def preflight(root: Path) -> None:
    if run(root, ["git", "branch", "--show-current"]).strip() != "main":
        raise ValueError("unattended execution requires main")
    # Read only: never adopt or modify another agent's state.
    if (root / "build/claude-campaign-guard.json").exists():
        raise ValueError("Claude campaign guard exists; finish or pause it in Claude first")
    graph(root, "validate")
    graph(root, "plan", "--check")
    ready(root)


def cli_command(executable: str, state: dict) -> list[str]:
    # Permission/model policy belongs to the user's Codex configuration.
    command = [executable, "exec"]
    if state.get("session_id"):
        command += ["resume", "--json", state["session_id"], "-"]
    else:
        command += ["--json", "-"]
    return command


def worker_command(root: Path, executable: str, state: dict) -> list[str]:
    return [sys.executable, str(Path(__file__).with_name("worker.py")),
            "--root", str(root), "--codex", executable, "--run-id", state["run_id"],
            "--session", state.get("session_id") or ""]


def invoke(root: Path, state: dict, executable: str, number: int) -> bool:
    folder = run_dir(root, state)
    folder.mkdir(parents=True, exist_ok=True)
    prompt = ("Process Spellbook's implementation plan using .agents/skills/process-plan/SKILL.md. "
              "You are the sole Codex writer inside the already-running supervisor; do not launch another. "
              f"Run record: {state['run_file']}. Phase scope: {state.get('phase')}. "
              "Read build/codex/campaign.json and its run's pause.json before actions. "
              "Inspect and preserve all side changes. Use independent fresh-context review. "
              "Commit and push each stamped section; never perform operator-only work. "
              "Continue until scope is exhausted; then write ## Closeout or PARKED with evidence. "
              "On operator stop or pause, call the Codex pause command and end immediately.")
    env = os.environ.copy()
    env["SPELLBOOK_CODEX_RUN"] = state["run_id"]
    completed = False
    with (folder / f"turn-{number}.jsonl").open("w", encoding="utf-8") as log, \
            (folder / f"turn-{number}.stderr.log").open("w", encoding="utf-8") as errors:
        with subprocess.Popen(worker_command(root, executable, state), cwd=root, env=env,
                              stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=errors,
                              text=True, encoding="utf-8", creationflags=NO_WINDOW) as proc:
            # The independent worker owns its lock BEFORE receiving a task. If
            # this supervisor dies before the handshake, EOF means no work.
            handshake = proc.stdout.readline()
            if json.loads(handshake).get("type") != "spellbook.worker.ready":
                raise ValueError("worker did not acquire its lifetime lock")
            proc.stdin.write(prompt)
            proc.stdin.close()
            for line in proc.stdout:
                log.write(line)
                log.flush()
                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if event.get("type") == "thread.started":
                    session = str(uuid.UUID(event["thread_id"]))
                    if state.get("session_id") and state["session_id"] != session:
                        raise ValueError("Codex resumed a different session")
                    state["session_id"] = session
                    write(state_path(root), state)
                if event.get("type") == "turn.completed":
                    completed = True
            code = proc.wait()
    return code == 0 and completed and bool(state.get("session_id"))


def supervise(root: Path, state: dict, executable: str) -> int:
    failures = 0
    unchanged = 0
    previous = fingerprint(root)
    while True:
        again, reason = decision(root, state)
        if not again:
            state["status"] = "paused" if paused(root, state) else "finished"
            write(state_path(root), state)
            print(f"codex campaign: {state['status']}: {reason}")
            return 0
        preflight(root)
        state["turns"] = state.get("turns", 0) + 1
        write(state_path(root), state)
        ok = invoke(root, state, executable, state["turns"])
        current = fingerprint(root)
        unchanged = unchanged + 1 if current == previous else 0
        previous = current
        failures = 0 if ok else failures + 1
        if not state.get("session_id") or failures >= 3 or unchanged >= 3:
            pause(root, state, "missing session identity, three CLI failures, or three turns without progress")
        print(f"codex campaign: turn {state['turns']}, completed={ok}, failures={failures}, unchanged={unchanged}", flush=True)
        if failures and not paused(root, state):
            time.sleep(5)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["audit", "start", "resume", "pause", "status"])
    parser.add_argument("--phase", type=int, choices=range(6))
    parser.add_argument("--codex", help="absolute path to the native codex.exe (not a shell shim)")
    args = parser.parse_args()
    root = ROOT
    if args.action == "status":
        state = read(state_path(root)) if state_path(root).exists() else {"status": "not started"}
        if state.get("run_id") and paused(root, state):
            state["status"] = "paused"
        print(json.dumps(state, indent=2))
        return 0
    if args.action == "pause":
        pause(root, read(state_path(root)), "operator requested pause")
        print("codex campaign: pause recorded; no further continuation; interrupt the active turn to stop immediately")
        return 0
    preflight(root)
    if args.action == "audit":
        ready(root, args.phase)
        print(graph(root, "query", "ready"))
        print("codex campaign: audit passed; no run started")
        return 0
    if not args.codex or not Path(args.codex).is_file() or Path(args.codex).suffix.lower() != ".exe":
        raise ValueError("start/resume needs --codex pointing to the installed native codex.exe")
    if args.action == "resume" and args.phase is not None:
        raise ValueError("resume retains the original phase scope")
    with lock(root):
        # A crashed/interrupted supervisor may have left its worker draining.
        # Never clear pause or start another worker until that process exits.
        with lock(root, "worker.lock"):
            pass
        if args.action == "start":
            if state_path(root).exists() and read(state_path(root)).get("status") != "finished":
                raise ValueError("an unfinished campaign exists; use explicit resume")
            run_id = str(uuid.uuid4())
            state = {"runner": "codex", "workspace": str(root), "run_id": run_id,
                     "session_id": None, "phase": args.phase, "status": "running",
                     "run_file": f"docs/codex-runs/{run_id}.md", "turns": 0}
            path = record_path(root, state)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("# Codex plan run\n\n## Phase repairs\n\n## Shipped-row verification\n\n## Gap audit\n\n## Sections\n\n## Critical events\n\n## Lessons\n", encoding="utf-8")
        else:
            state = read(state_path(root))
            if not owned(root, state) or state["status"] == "finished" or not state.get("session_id"):
                raise ValueError("no owned, resumable session")
            # Only an explicit resume removes this run's pause marker.
            (run_dir(root, state) / "pause.json").unlink(missing_ok=True)
            (run_dir(root, state) / "stop-state.json").unlink(missing_ok=True)
            state["status"] = "running"
        write(state_path(root), state)
        try:
            return supervise(root, state, args.codex)
        except (Exception, KeyboardInterrupt):
            pause(root, state, "supervisor interrupted or failed; explicit resume required")
            state["status"] = "paused"
            write(state_path(root), state)
            raise


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    try:
        sys.exit(main())
    except Exception as error:
        print(f"codex campaign: {error}", file=sys.stderr)
        sys.exit(1)
