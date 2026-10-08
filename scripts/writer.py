"""Agent-neutral writer selection. No model, hook, or agent runner is loaded."""
from __future__ import annotations

import argparse
import contextlib
import json
import os
from pathlib import Path
import sys
import uuid

ROOT = Path(__file__).resolve().parent.parent
WRITERS = ("codex", "claude")


def selected(root: Path) -> str:
    data = json.loads((root / "writer.json").read_text(encoding="utf-8"))
    if data.get("schema_version") != 1 or data.get("primary_writer") not in WRITERS:
        raise ValueError("writer.json must select codex or claude with schema_version 1")
    return data["primary_writer"]


def require(root: Path, agent: str) -> None:
    current = selected(root)
    if agent != current:
        raise ValueError(f"primary writer is {current}; {agent} may review but must not implement or resume")


@contextlib.contextmanager
def file_lock(path: Path):
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


def selection_lock(root: Path):
    return file_lock(root / "build/writer-selection.lock")


def ensure_idle(root: Path) -> None:
    """Read-only inspection of foreign state; never adopt or clear it."""
    if (root / "build/claude-campaign-guard.json").exists():
        raise ValueError("Claude run guard exists; pause/finish it through Claude before switching")
    with contextlib.ExitStack() as locks:
        for name in ("supervisor.lock", "worker.lock"):
            path = root / "build/codex" / name
            if path.exists():
                locks.enter_context(file_lock(path))
        state_path = root / "build/codex/campaign.json"
        if state_path.exists():
            data = json.loads(state_path.read_text(encoding="utf-8"))
            if data.get("runner") != "codex" or Path(data.get("workspace", "")).resolve() != root.resolve():
                raise ValueError("unrecognized Codex ownership state; inspect it before switching")
            run_id = str(uuid.UUID(data["run_id"]))
            paused = (root / "build/codex/runs" / run_id / "pause.json").exists()
            if data.get("status") not in ("paused", "finished") and not paused:
                raise ValueError("Codex campaign is not paused/finished; pause it before switching")


def select(root: Path, agent: str) -> str:
    if agent not in WRITERS:
        raise ValueError("writer must be codex or claude")
    with selection_lock(root):
        if selected(root) == agent:
            return agent
        ensure_idle(root)
        path = root / "writer.json"
        temporary = root / (".writer-" + uuid.uuid4().hex + ".tmp")
        try:
            temporary.write_text(json.dumps({"schema_version": 1, "primary_writer": agent}, indent=2) + "\n", encoding="utf-8")
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)
    return agent


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    commands.add_parser("status")
    for command in ("select", "assert"):
        commands.add_parser(command).add_argument("writer", choices=WRITERS)
    args = parser.parse_args()
    if args.action == "select":
        current = select(ROOT, args.writer)
    elif args.action == "assert":
        require(ROOT, args.writer)
        current = args.writer
    else:
        current = selected(ROOT)
    print(f"primary writer: {current}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError) as error:
        print(f"writer: selection refused: {error}. No agent runtime was changed.", file=sys.stderr)
        sys.exit(1)
