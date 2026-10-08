"""Hold worker ownership even if its supervisor crashes or is interrupted."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

from campaign import cli_command, lock, NO_WINDOW, owned, paused, read, state_path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--codex', required=True)
    parser.add_argument('--run-id', required=True)
    parser.add_argument('--session', required=True)
    args = parser.parse_args()
    with lock(args.root, 'worker.lock'):
        print(json.dumps({'type': 'spellbook.worker.ready'}), flush=True)
        prompt = sys.stdin.read()
        if not prompt.strip():
            return 1
        state = read(state_path(args.root))
        if not owned(args.root, state) or state['run_id'] != args.run_id or paused(args.root, state):
            return 1
        if (state.get('session_id') or '') != args.session:
            return 1
        # No shell: child inherits JSON stdout and stderr log handles. The lock
        # lives in this process until the actual Codex child has exited.
        with subprocess.Popen(cli_command(args.codex, state), cwd=args.root,
                              stdin=subprocess.PIPE, text=True, encoding='utf-8',
                              creationflags=NO_WINDOW) as child:
            child.stdin.write(prompt)
            child.stdin.close()
            while True:
                try:
                    return child.wait()
                except KeyboardInterrupt:
                    # Do not orphan the child and release its ownership lock.
                    continue


if __name__ == '__main__':
    sys.exit(main())
