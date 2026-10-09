"""Claude run guard registration tests; no Claude session or cron job is started."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

spec = importlib.util.spec_from_file_location('claude_guard', ROOT / '.claude/scripts/write-campaign-guard.py')
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


class ClaudeGuardTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='spellbook-claude-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.record = self.root / 'docs/phase-runs/probe.md'
        self.record.parent.mkdir(parents=True)
        self.record.write_text('# Probe')
        self.path = self.root / 'build/claude-campaign-guard.json'

    def register(self, session='claude-session', cron='test-cron'):
        guard.register(self.root, session, 0, 'docs/phase-runs/probe.md', cron)

    def test_registration_writes_the_guard(self):
        self.register()
        written = json.loads(self.path.read_text(encoding='utf-8'))
        self.assertEqual(written['runner'], 'claude')
        self.assertEqual(written['session_id'], 'claude-session')
        self.assertEqual(written['run_file'], 'docs/phase-runs/probe.md')
        self.assertEqual(list(self.path.parent.glob('*.tmp')), [])

    def test_same_session_may_repoint_but_another_may_not(self):
        self.register()
        self.register(cron='new-cron')  # Repointing by the same session is permitted.
        self.assertEqual(json.loads(self.path.read_text(encoding='utf-8'))['cron_id'], 'new-cron')
        before = self.path.read_bytes()
        with self.assertRaisesRegex(ValueError, 'another Claude session'):
            self.register('other-session')
        self.assertEqual(self.path.read_bytes(), before)

    def test_missing_arguments_are_refused(self):
        with self.assertRaisesRegex(ValueError, 'phase 0 through 5'):
            self.register(session='')
        with self.assertRaisesRegex(ValueError, 'phase 0 through 5'):
            guard.register(self.root, 's', 6, 'docs/phase-runs/probe.md', 'cron')
        self.assertFalse(self.path.exists())

    def test_held_lock_refuses_registration(self):
        with guard.registration_lock(self.root):
            with self.assertRaisesRegex(OSError, 'registration in progress'):
                self.register()
        self.assertFalse(self.path.exists())
        self.register()  # The lock is released afterwards.
        self.assertFalse((self.root / 'build/claude-campaign-guard.lock').exists())

    def test_escaping_or_missing_record_is_refused(self):
        (self.root / 'outside.md').write_text('# Outside')
        for run_file in ('outside.md', 'docs/phase-runs/missing.md'):
            with self.assertRaisesRegex(ValueError, 'existing file under docs/phase-runs'):
                guard.register(self.root, 's', 0, run_file, 'cron')
        self.assertFalse(self.path.exists())


if __name__ == '__main__':
    unittest.main()
