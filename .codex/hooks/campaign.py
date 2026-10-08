"""Native Codex lifecycle entrypoint. JSON stdin/stdout; no agent-shared hooks."""
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from campaign import ROOT, hook, pause, read, state_path, owned

event = None
try:
    event = json.load(sys.stdin)
    print(json.dumps(hook(ROOT, event)))
except Exception as error:
    # End the turn but prevent the supervisor silently reentering a broken guard.
    try:
        state = read(state_path(ROOT))
        if isinstance(event, dict) and owned(ROOT, state) and state.get("session_id") == event.get("session_id"):
            pause(ROOT, state, "hook error: " + str(error))
    except Exception:
        pass
    print(json.dumps({"systemMessage": "Codex campaign hook failed; inspect build/codex before resuming: " + str(error)}))
