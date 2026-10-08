"""Neutral writer-selector tests; all changes use temporary checkouts."""
import json
from pathlib import Path
import tempfile
import unittest
import uuid

import writer


class WriterTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='spellbook-writer-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        (self.root / 'writer.json').write_text('{"schema_version":1,"primary_writer":"codex"}')

    def test_switch_both_directions_and_require_selected_writer(self):
        self.assertEqual(writer.select(self.root, 'claude'), 'claude')
        writer.require(self.root, 'claude')
        with self.assertRaisesRegex(ValueError, 'primary writer is claude'):
            writer.require(self.root, 'codex')
        self.assertEqual(writer.select(self.root, 'codex'), 'codex')
        writer.require(self.root, 'codex')

    def test_idempotent_selection_does_not_rewrite_file(self):
        original = (self.root / 'writer.json').read_bytes()
        writer.select(self.root, 'codex')
        self.assertEqual(original, (self.root / 'writer.json').read_bytes())

    def test_invalid_or_missing_selection_fails_closed(self):
        for contents in ('{}', '{"schema_version":1,"primary_writer":"other"}', 'bad JSON'):
            (self.root / 'writer.json').write_text(contents)
            with self.assertRaises(ValueError):
                writer.select(self.root, 'claude')
        (self.root / 'writer.json').unlink()
        with self.assertRaises(OSError):
            writer.selected(self.root)

    def test_active_claude_guard_refuses_switch_without_mutation(self):
        path = self.root / 'build/claude-campaign-guard.json'
        path.parent.mkdir()
        path.write_text('even an uncertain legacy guard is preserved')
        before = path.read_bytes()
        with self.assertRaisesRegex(ValueError, 'Claude run guard exists'):
            writer.select(self.root, 'claude')
        self.assertEqual(path.read_bytes(), before)
        self.assertEqual(writer.selected(self.root), 'codex')

    def test_live_codex_locks_and_transition_lock_refuse_switch(self):
        for name in ('build/codex/supervisor.lock', 'build/codex/worker.lock', 'build/writer-selection.lock'):
            with writer.file_lock(self.root / name):
                with self.assertRaises(OSError):
                    writer.select(self.root, 'claude')
            self.assertEqual(writer.selected(self.root), 'codex')

    def test_paused_codex_state_survives_round_trip_switch(self):
        run_id = str(uuid.uuid4())
        path = self.root / 'build/codex/campaign.json'
        path.parent.mkdir(parents=True)
        state = {'runner':'codex', 'workspace':str(self.root), 'run_id':run_id, 'status':'running'}
        path.write_text(json.dumps(state))
        with self.assertRaisesRegex(ValueError, 'not paused/finished'):
            writer.select(self.root, 'claude')
        pause = self.root / 'build/codex/runs' / run_id / 'pause.json'
        pause.parent.mkdir(parents=True)
        pause.write_text('{"reason":"operator pause"}')
        before = {p: p.read_bytes() for p in (path, pause)}
        writer.select(self.root, 'claude')
        writer.select(self.root, 'codex')
        self.assertEqual(before, {p: p.read_bytes() for p in before})

    def test_unrecognized_runtime_state_cannot_be_silently_cleared(self):
        path = self.root / 'build/codex/campaign.json'
        path.parent.mkdir(parents=True)
        path.write_text('{"runner":"someone-else"}')
        with self.assertRaisesRegex(ValueError, 'unrecognized Codex ownership'):
            writer.select(self.root, 'claude')
        self.assertTrue(path.exists())


if __name__ == '__main__':
    unittest.main()
