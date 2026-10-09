"""Readback safety and real SQLite round-trip proofs on isolated files."""
from contextlib import closing
import hashlib
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import unittest

import dbread


class ReadbackTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="spellbook-dbread-")
        self.path = Path(self.temp.name) / "donn\u00e9es #100%.db"
        with closing(sqlite3.connect(self.path)) as db:
            db.execute("CREATE TABLE entries (title TEXT, data BLOB)")
            db.execute("INSERT INTO entries VALUES (?,?)", ("\u00e9\U0001f4da", b"\x00\xff"))
            db.execute("PRAGMA user_version=7")
            db.commit()
        self.before = hashlib.sha256(self.path.read_bytes()).hexdigest()

    def tearDown(self):
        self.assertEqual(self.before, hashlib.sha256(self.path.read_bytes()).hexdigest())
        self.temp.cleanup()

    def test_unicode_and_uri_special_path_round_trip(self):
        self.assertEqual(dbread.read_query(self.path, "SELECT title,data FROM entries"),
                         {"columns": ["title", "data"], "rows": [["\u00e9\U0001f4da", {"blob_hex": "00ff"}]]})
        self.assertEqual(dbread.read_query(self.path, "PRAGMA user_version")["rows"], [[7]])
        self.assertEqual(dbread.read_query(self.path, "PRAGMA integrity_check")["rows"], [["ok"]])

    def test_mutations_and_attachments_are_rejected(self):
        other = Path(self.temp.name) / "attached.db"
        for query in ["DELETE FROM entries", "UPDATE entries SET title='changed'",
                      "CREATE TEMP TABLE noise (a)", "PRAGMA user_version=99",
                      "PRAGMA query_only=OFF", "PRAGMA journal_mode=WAL",
                      "PRAGMA writable_schema=ON", "VACUUM",
                      f"ATTACH DATABASE '{other.as_posix()}' AS other",
                      "SELECT load_extension('missing')", "SELECT 1; DELETE FROM entries"]:
            with self.subTest(query=query), self.assertRaises(sqlite3.Error):
                dbread.read_query(self.path, query)
            self.assertFalse(other.exists())

    def test_missing_database_is_not_created(self):
        missing = Path(self.temp.name) / "missing.db"
        with self.assertRaises(OSError):
            dbread.read_query(missing, "SELECT 1")
        self.assertFalse(missing.exists())

    def test_row_and_work_limits(self):
        with self.assertRaises(ValueError):
            dbread.read_query(self.path, "SELECT 1 UNION ALL SELECT 2", max_rows=1)
        with self.assertRaises(sqlite3.Error):
            dbread.read_query(self.path, "WITH RECURSIVE n(x) AS (VALUES(1) UNION ALL SELECT x+1 FROM n) SELECT sum(x) FROM n", timeout=0.01)

    def test_reads_current_wal_without_immutable_shortcut(self):
        live = Path(self.temp.name) / "live.db"
        with closing(sqlite3.connect(live)) as writer:
            writer.execute("PRAGMA journal_mode=WAL")
            writer.execute("CREATE TABLE values_seen (v)")
            writer.execute("INSERT INTO values_seen VALUES (42)")
            writer.commit()
            self.assertEqual(dbread.read_query(live, "SELECT v FROM values_seen")["rows"], [[42]])

    def test_cli_failure_is_nonzero_without_success_json(self):
        result = subprocess.run([sys.executable, str(Path(dbread.__file__)), str(self.path), "DELETE FROM entries"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
        self.assertIn("dbread:", result.stderr)


if __name__ == "__main__":
    unittest.main()
