"""Failure proofs for capture/receipt publication, including retained recovery."""
import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from publish import publish


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.source = self.root / "new.png"
        self.source.write_bytes(b"new capture")
        self.destination = self.root / "published.png"
        self.receipt = self.root / "published.png.json"
        self.destination.write_bytes(b"old capture")
        self.receipt.write_bytes(b"old receipt")
        self.manifest = self.root / "manifest.json"
        self.manifest.write_text(json.dumps({"Capture": {"Sha256": hashlib.sha256(self.source.read_bytes()).hexdigest()},
                                             "PublishedPath": str(self.destination)}), encoding="utf-8")
        self.recovery = self.root / "recovery"

    def tearDown(self):
        self.temp.cleanup()

    def run_publish(self):
        publish(self.source, self.manifest, self.destination, self.recovery)

    def test_success_retains_both_originals(self):
        self.run_publish()
        self.assertEqual(self.destination.read_bytes(), self.source.read_bytes())
        self.assertEqual(self.receipt.read_bytes(), self.manifest.read_bytes())
        self.assertEqual((self.recovery / self.destination.name).read_bytes(), b"old capture")
        self.assertEqual((self.recovery / self.receipt.name).read_bytes(), b"old receipt")

    def test_receipt_failure_restores_image_and_preserves_receipt(self):
        replace = os.replace

        def fail_receipt(source, target):
            if target == self.receipt:
                raise PermissionError("receipt is locked")
            return replace(source, target)

        with patch("publish.os.replace", side_effect=fail_receipt), self.assertRaises(PermissionError):
            self.run_publish()
        self.assertEqual(self.destination.read_bytes(), b"old capture")
        self.assertEqual(self.receipt.read_bytes(), b"old receipt")

    def test_restoration_failure_keeps_recovery(self):
        replace = os.replace
        calls = 0

        def fail_after_image(source, target):
            nonlocal calls
            calls += 1
            if calls > 1:
                raise PermissionError("destination locked")
            return replace(source, target)

        with patch("publish.os.replace", side_effect=fail_after_image), self.assertRaisesRegex(RuntimeError, "recovery"):
            self.run_publish()
        self.assertEqual((self.recovery / self.destination.name).read_bytes(), b"old capture")
        self.assertEqual((self.recovery / self.receipt.name).read_bytes(), b"old receipt")

    def test_wrong_hash_preserves_previous_pair(self):
        self.source.write_bytes(b"tampered")
        with self.assertRaisesRegex(ValueError, "hash"):
            self.run_publish()
        self.assertEqual(self.destination.read_bytes(), b"old capture")
        self.assertEqual(self.receipt.read_bytes(), b"old receipt")

    def test_missing_image_preserves_previous_pair(self):
        self.source.unlink()
        with self.assertRaises(FileNotFoundError):
            self.run_publish()
        self.assertEqual(self.destination.read_bytes(), b"old capture")
        self.assertEqual(self.receipt.read_bytes(), b"old receipt")


if __name__ == "__main__":
    unittest.main()
