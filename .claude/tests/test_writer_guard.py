"""Claude-only registration tests; no Claude session or cron job is started."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
import writer

spec = importlib.util.spec_from_file_location('claude_guard', ROOT / '.claude/scripts/write-campaign-guard.py')
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


class ClaudeGuardTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='spellbook-claude-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        (self.root / 'writer.json').write_text('{"schema_version":1,"primary_writer":"codex"}')
        self.record = self.root / 'docs/phase-runs/probe.md'
        self.record.parent.mkdir(parents=True)
        self.record.write_text('# Probe')

    def register(self, session='claude-session'):
        guard.register(self.root, session, 0, 'docs/phase-runs/probe.md', 'test-cron')

    def test_wrong_writer_refuses_guard_creation(self):
        with self.assertRaisesRegex(ValueError, 'primary writer is codex'):
            self.register()
        self.assertFalse((self.root / 'build/claude-campaign-guard.json').exists())

    def test_registration_prevents_switch_until_guard_is_removed(self):
        writer.select(self.root, 'claude')
        self.register()
        self.register()  # Repointing by the same session is permitted.
        with self.assertRaisesRegex(ValueError, 'Claude run guard exists'):
            writer.select(self.root, 'codex')
        with self.assertRaisesRegex(ValueError, 'another Claude session'):
            self.register('other-session')
        (self.root / 'build/claude-campaign-guard.json').unlink()
        self.assertEqual(writer.select(self.root, 'codex'), 'codex')

    def test_transition_cannot_race_registration(self):
        writer.select(self.root, 'claude')
        with writer.selection_lock(self.root):
            with self.assertRaises(OSError):
                self.register()
        self.assertFalse((self.root / 'build/claude-campaign-guard.json').exists())

    def test_escaping_record_is_refused(self):
        writer.select(self.root, 'claude')
        with self.assertRaisesRegex(ValueError, 'existing file under docs/phase-runs'):
            guard.register(self.root, 's', 0, 'writer.json', 'cron')


if __name__ == '__main__':
    unittest.main()
