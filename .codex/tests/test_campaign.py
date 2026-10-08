"""Behavioral probes, never the real plan or a paid model invocation."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import uuid

SCRIPTS = Path(__file__).resolve().parents[1] / 'scripts'
sys.path.insert(0, str(SCRIPTS))
import campaign as c


class CampaignTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='spellbook-codex-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        for args in [['git', 'init', '-b', 'main'], ['git', 'config', 'user.name', 'Probe'],
                     ['git', 'config', 'user.email', 'probe@example.invalid']]:
            c.run(self.root, args)
        (self.root / '.gitignore').write_text('build/\n', encoding='utf-8')
        (self.root / 'content.txt').write_text('initial', encoding='utf-8')
        c.run(self.root, ['git', 'add', '.'])
        c.run(self.root, ['git', '-c', 'core.hooksPath=/dev/null', 'commit', '-m', 'fixture'])
        run_id = str(uuid.uuid4())
        self.state = {'runner': 'codex', 'workspace': str(self.root), 'run_id': run_id,
                      'session_id': str(uuid.uuid4()), 'status': 'running', 'phase': None,
                      'run_file': f'docs/codex-runs/{run_id}.md', 'turns': 0}
        self.record = c.record_path(self.root, self.state)
        self.record.parent.mkdir(parents=True)
        self.record.write_text('# Probe\n', encoding='utf-8')
        c.write(c.state_path(self.root), self.state)
        self.event = {'hook_event_name': 'Stop', 'session_id': self.state['session_id'], 'cwd': str(self.root)}

    def test_unrelated_session_and_foreign_owner_are_not_blocked(self):
        event = dict(self.event, session_id='someone-else')
        self.assertEqual(c.hook(self.root, event), {})
        self.state['runner'] = 'claude'
        c.write(c.state_path(self.root), self.state)
        self.assertEqual(c.hook(self.root, self.event), {})
        self.assertFalse(c.run_dir(self.root, self.state).exists())

    def test_missing_guard_is_inert(self):
        c.state_path(self.root).unlink()
        self.assertEqual(c.hook(self.root, self.event), {})

    @patch.object(c, 'ready', return_value=['D00 T01 §1'])
    def test_open_run_continues_then_stall_persists_pause(self, _):
        for _ in range(3):
            self.assertEqual(c.hook(self.root, self.event)['decision'], 'block')
        self.assertIn('paused', c.hook(self.root, self.event)['systemMessage'])
        self.assertTrue(c.paused(self.root, self.state))
        self.assertEqual(c.hook(self.root, self.event), {})

    @patch.object(c, 'ready', return_value=['D00 T01 §1'])
    def test_untracked_content_is_progress_but_record_chatter_is_not(self, _):
        c.hook(self.root, self.event)
        before = c.fingerprint(self.root)
        self.record.write_text('# Probe\nchatter\n', encoding='utf-8')
        self.assertEqual(before, c.fingerprint(self.root))
        c.run(self.root, ['git', 'add', 'docs/codex-runs'])
        c.run(self.root, ['git', '-c', 'core.hooksPath=/dev/null', 'commit', '-m', 'record only'])
        self.assertEqual(before, c.fingerprint(self.root))
        new_file = self.root / 'new.txt'
        new_file.write_text('one')
        first = c.fingerprint(self.root)
        new_file.write_text('two')
        self.assertNotEqual(first, c.fingerprint(self.root))
        c.hook(self.root, self.event)
        self.assertEqual(c.read(c.run_dir(self.root, self.state) / 'stop-state.json')['blocks'], 1)

    def test_interrupt_persists_pause_only_for_owner(self):
        c.hook(self.root, dict(self.event, hook_event_name='Interrupt', session_id='other'))
        self.assertFalse(c.paused(self.root, self.state))
        self.assertEqual(c.hook(self.root, dict(self.event, hook_event_name='Interrupt')), {})
        self.assertTrue(c.paused(self.root, self.state))

    @patch.object(c, 'ready', return_value=[])
    def test_no_work_requires_honest_terminal_record(self, _):
        self.assertTrue(c.decision(self.root, self.state)[0])
        self.record.write_text('# Probe\nPARKED now operator-only remainder\n')
        self.assertFalse(c.decision(self.root, self.state)[0])
        self.record.write_text('# Probe\n## Closeout\n')
        self.assertFalse(c.decision(self.root, self.state)[0])

    @patch.object(c, 'ready', return_value=['D01 T01 §1'])
    def test_false_closeout_does_not_finish_campaign(self, _):
        self.record.write_text('# Probe\n## Closeout\n')
        self.assertTrue(c.decision(self.root, self.state)[0])

    def test_run_path_cannot_escape(self):
        self.state['run_file'] = '../outside.md'
        with self.assertRaises(ValueError):
            c.record_path(self.root, self.state)

    def test_ready_filters_operator_and_phase(self):
        output = 'D00 T01 §1  First\nD01 T01 §1  Next\n  D99 T01 §1  Human\n2 runnable now, 1 runnable elsewhere\n'
        (self.root / 'todo').mkdir()
        (self.root / 'todo/implementation-plan.md').write_text('### Phase 0 -- First\n| [ ] | `D00 T01 §1` |\n### Phase 1 -- Next\n| [ ] | `D01 T01 §1` |\n', encoding='utf-8')
        with patch.object(c, 'graph', return_value=output):
            self.assertEqual(c.ready(self.root), ['D00 T01 §1', 'D01 T01 §1'])
            self.assertEqual(c.ready(self.root, 1), ['D01 T01 §1'])
            with self.assertRaises(ValueError):
                c.ready(self.root, 4)
        with patch.object(c, 'graph', return_value='D99 T01 §1  Human\n1 runnable now, 0 runnable elsewhere\n'):
            with self.assertRaises(ValueError):
                c.ready(self.root)
        with patch.object(c, 'graph', return_value='broken output'):
            with self.assertRaises(ValueError):
                c.ready(self.root)

    def test_os_lock_rejects_second_supervisor(self):
        with c.lock(self.root):
            with self.assertRaises(OSError):
                with c.lock(self.root):
                    self.fail('second writer acquired the lock')
        with c.lock(self.root):
            pass

    @patch.object(c, 'ready', return_value=['D00 T01 §1'])
    @patch.object(c, 'preflight')
    def test_supervisor_retries_then_pauses_cli_failures(self, *_):
        with patch.object(c, 'invoke', return_value=False) as invoke, patch.object(c.time, 'sleep'):
            c.supervise(self.root, self.state, 'unused.exe')
        self.assertEqual(invoke.call_count, 3)
        self.assertTrue(c.paused(self.root, self.state))
        self.assertEqual(c.read(c.state_path(self.root))['status'], 'paused')

    @patch.object(c, 'ready', return_value=['D00 T01 §1'])
    @patch.object(c, 'preflight')
    def test_success_without_progress_cannot_loop_forever(self, *_):
        with patch.object(c, 'invoke', return_value=True) as invoke:
            c.supervise(self.root, self.state, 'unused.exe')
        self.assertEqual(invoke.call_count, 3)
        self.assertTrue(c.paused(self.root, self.state))

    @patch.object(c, 'preflight')
    def test_supervisor_continues_then_finishes_after_closeout(self, _):
        def turn(root, state, executable, number):
            (root / 'content.txt').write_text(str(number))
            if number == 2:
                self.record.write_text('## Closeout\n')
            return True
        with patch.object(c, 'ready', side_effect=lambda *a: [] if self.state['turns'] >= 2 else ['D00 T01 §1']), patch.object(c, 'invoke', side_effect=turn):
            c.supervise(self.root, self.state, 'unused.exe')
        self.assertEqual(self.state['turns'], 2)
        self.assertEqual(self.state['status'], 'finished')

    def test_cli_uses_exact_session_and_no_permission_bypass(self):
        command = c.cli_command('codex.exe', self.state)
        self.assertEqual(command, ['codex.exe', 'exec', 'resume', '--json', self.state['session_id'], '-'])
        self.state['session_id'] = None
        self.assertEqual(c.cli_command('codex.exe', self.state), ['codex.exe', 'exec', '--json', '-'])

    def test_real_child_transport_captures_identity_and_completion(self):
        session = str(uuid.uuid4())
        script = self.root / 'fake_cli.py'
        script.write_text('import sys, json\nprint(json.dumps({"type":"spellbook.worker.ready"}), flush=True)\nsys.stdin.read()\nprint(json.dumps({"type":"thread.started","thread_id":' + repr(session) + '}))\nprint(json.dumps({"type":"turn.completed"}))\n', encoding='utf-8')
        self.state['session_id'] = None
        with patch.object(c, 'worker_command', return_value=[sys.executable, str(script)]):
            self.assertTrue(c.invoke(self.root, self.state, 'unused.exe', 1))
        self.assertEqual(c.read(c.state_path(self.root))['session_id'], session)
        self.assertTrue((c.run_dir(self.root, self.state) / 'turn-1.jsonl').exists())

    def test_cli_exit_zero_without_completion_is_failure(self):
        script = self.root / 'fake_cli.py'
        script.write_text('import sys\nprint(\'{"type":"spellbook.worker.ready"}\', flush=True)\nsys.stdin.read()\n', encoding='utf-8')
        with patch.object(c, 'worker_command', return_value=[sys.executable, str(script)]):
            self.assertFalse(c.invoke(self.root, self.state, 'unused.exe', 1))

    def test_resume_reuses_owned_identity_and_scope_and_clears_only_its_markers(self):
        c.pause(self.root, self.state, 'operator pause')
        unrelated = self.root / 'build/unrelated.json'
        unrelated.write_text('preserve')
        self.state['phase'] = 2
        c.write(c.state_path(self.root), self.state)
        native = self.root / 'codex.exe'
        native.write_bytes(b'fixture')
        with patch.object(c, 'ROOT', self.root), patch.object(c, 'preflight'), patch.object(c, 'supervise', return_value=0) as supervisor, patch.object(sys, 'argv', ['campaign.py', 'resume', '--codex', str(native)]):
            self.assertEqual(c.main(), 0)
        resumed = supervisor.call_args.args[1]
        self.assertEqual(resumed['session_id'], self.state['session_id'])
        self.assertEqual(resumed['phase'], 2)
        self.assertFalse(c.paused(self.root, resumed))
        self.assertEqual(unrelated.read_text(), 'preserve')

    def test_start_does_not_overwrite_paused_campaign(self):
        c.pause(self.root, self.state, 'operator pause')
        before = c.state_path(self.root).read_bytes()
        native = self.root / 'codex.exe'
        native.write_bytes(b'fixture')
        with patch.object(c, 'ROOT', self.root), patch.object(c, 'preflight'), patch.object(sys, 'argv', ['campaign.py', 'start', '--codex', str(native)]):
            with self.assertRaisesRegex(ValueError, 'unfinished campaign'):
                c.main()
        self.assertEqual(c.state_path(self.root).read_bytes(), before)
        self.assertTrue(c.paused(self.root, self.state))

    def test_cli_cannot_replace_session_identity(self):
        script = self.root / 'fake_cli.py'
        other = str(uuid.uuid4())
        script.write_text('import sys, json\nprint(json.dumps({"type":"spellbook.worker.ready"}), flush=True)\nsys.stdin.read()\nprint(json.dumps({"type":"thread.started","thread_id":' + repr(other) + '}))\n', encoding='utf-8')
        with patch.object(c, 'worker_command', return_value=[sys.executable, str(script)]):
            with self.assertRaisesRegex(ValueError, 'different session'):
                c.invoke(self.root, self.state, 'unused.exe', 1)
        self.assertEqual(c.read(c.state_path(self.root))['session_id'], self.state['session_id'])

    def test_foreign_campaign_guard_is_not_adopted_or_modified(self):
        path = self.root / 'build/claude-campaign-guard.json'
        path.write_text('{"runner":"claude"}')
        with self.assertRaisesRegex(ValueError, 'Claude campaign guard exists'):
            c.preflight(self.root)
        self.assertEqual(path.read_text(), '{"runner":"claude"}')

    def test_interrupted_supervisor_cannot_resume_while_worker_is_alive(self):
        # Run the REAL worker wrapper with a bounded fake CLI. Its lock must
        # outlive the supervisor's Python Popen context on KeyboardInterrupt.
        bootstrap = self.root / 'worker_bootstrap.py'
        fake = self.root / 'slow_cli.py'
        fake.write_text('import sys, time\nsys.stdin.read()\ntime.sleep(2)\n', encoding='utf-8')
        bootstrap.write_text('import sys\nsys.path.insert(0, ' + repr(str(SCRIPTS)) + ')\nimport worker\nworker.cli_command = lambda *a: [sys.executable, ' + repr(str(fake)) + ']\nraise SystemExit(worker.main())\n', encoding='utf-8')
        command = [sys.executable, str(bootstrap), '--root', str(self.root), '--codex', 'unused.exe',
                   '--run-id', self.state['run_id'], '--session', self.state['session_id']]
        original_popen = subprocess.Popen
        children = []

        class InterruptedOutput:
            def __init__(self, stream):
                self.stream = stream
            def readline(self):
                return self.stream.readline()
            def __iter__(self):
                raise KeyboardInterrupt()
            def close(self):
                self.stream.close()

        def launch(*a, **kw):
            child = original_popen(*a, **kw)
            children.append(child)
            child.stdout = InterruptedOutput(child.stdout)
            return child

        try:
            with c.lock(self.root):
                with patch.object(c, 'worker_command', return_value=command), patch.object(c.subprocess, 'Popen', side_effect=launch):
                    with self.assertRaises(KeyboardInterrupt):
                        c.invoke(self.root, self.state, 'unused.exe', 1)
                c.pause(self.root, self.state, 'interrupted supervisor')
            self.assertIsNone(children[0].poll())
            native = self.root / 'codex.exe'
            native.write_bytes(b'fixture')
            with patch.object(c, 'ROOT', self.root), patch.object(c, 'preflight'), patch.object(sys, 'argv', ['campaign.py', 'resume', '--codex', str(native)]):
                with self.assertRaises(OSError):
                    c.main()
            self.assertTrue(c.paused(self.root, self.state))
        finally:
            for child in children:
                child.wait(timeout=10)
        with c.lock(self.root, 'worker.lock'):
            pass

    @unittest.skipUnless(os.name == 'nt', 'Windows hook command')
    def test_configured_hook_command_from_subdirectory(self):
        source = SCRIPTS.parent
        shutil.copytree(source / 'hooks', self.root / '.codex/hooks')
        (self.root / '.codex/scripts').mkdir()
        shutil.copy2(SCRIPTS / 'campaign.py', self.root / '.codex/scripts/campaign.py')
        # Interrupt needs no TODO graph and proves JSON stdin, ownership, and cwd resolution.
        hooks = json.loads((source / 'hooks.json').read_text(encoding='utf-8'))
        command = hooks['hooks']['Interrupt'][0]['hooks'][0]['command']
        powershell_body = command.split('-Command "', 1)[1][:-1]
        nested = self.root / 'nested'
        nested.mkdir()
        result = subprocess.run(['pwsh', '-NoProfile', '-NonInteractive', '-Command', powershell_body],
                                cwd=nested, input=json.dumps(dict(self.event, hook_event_name='Interrupt')),
                                capture_output=True, text=True, creationflags=c.NO_WINDOW, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {})
        self.assertTrue(c.paused(self.root, self.state))


if __name__ == '__main__':
    unittest.main()
