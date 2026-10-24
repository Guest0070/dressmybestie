"""Tests for the audio pipeline (tools/audio). Run:  python -m unittest discover -s tests -p "test_*.py"
Needs numpy; the end-to-end check also needs ffmpeg and the processed files."""

import json
import sys
import unittest
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "audio"))

import audiolib as A  # noqa: E402
import process_sfx  # noqa: E402
import sync_ids  # noqa: E402
from sfx_catalog import CATALOG  # noqa: E402

SAMPLE = """Config.Sounds = {
\t-- UI
\tClick = "rbxasset://sounds/clickfast.wav", -- soft tap
\tReady = 0, -- stylist taps READY
\tRunwayMusic = 1839940316, -- "Jump Up"
} :: { [string]: number | string }
"""


class ConfigParsing(unittest.TestCase):
    def test_parses_strings_numbers_and_zero(self):
        sounds = A.config_sounds(SAMPLE)
        self.assertEqual(sounds["Click"]["value"], "rbxasset://sounds/clickfast.wav")
        self.assertEqual(sounds["Ready"]["value"], 0)
        self.assertEqual(sounds["RunwayMusic"]["value"], 1839940316)

    def test_value_status(self):
        self.assertEqual(A.value_status(0), "silent")
        self.assertEqual(A.value_status("rbxasset://sounds/clickfast.wav"), "verified_builtin")
        self.assertEqual(A.value_status("rbxasset://sounds/nope.wav"), "unverified_builtin")
        self.assertEqual(A.value_status(1839940316), "verified_store_audio")
        self.assertEqual(A.value_status(123), "uploaded_or_unverified_id")

    def test_real_config_has_every_catalog_key(self):
        sounds = A.config_sounds()
        for entry in CATALOG:
            for key in entry["keys"]:
                self.assertIn(key, sounds, f"{entry['id']} fills {key}")


class SyncIds(unittest.TestCase):
    def test_rewrites_only_the_value_and_keeps_comments(self):
        text, log = sync_ids.apply_ids(SAMPLE, {"Ready": 987654321})
        self.assertIn("\tReady = 987654321, -- stylist taps READY\n", text)
        self.assertIn('\tClick = "rbxasset://sounds/clickfast.wav", -- soft tap\n', text)
        self.assertEqual(log, ["Ready: 0 -> 987654321"])

    def test_keeps_crlf_line_endings(self):
        crlf = SAMPLE.replace("\n", "\r\n")
        text, _ = sync_ids.apply_ids(crlf, {"Ready": 42})
        self.assertIn("\tReady = 42, -- stylist taps READY\r\n", text)
        self.assertEqual(text.count("\r\n"), crlf.count("\r\n"))

    def test_rejects_bad_ids(self):
        for bad in ("", "abc", "0", "-5", "12a"):
            with self.assertRaises(ValueError):
                sync_ids.parse_asset_id(bad)
        self.assertEqual(sync_ids.parse_asset_id("rbxassetid://123"), 123)


class Processing(unittest.TestCase):
    def test_trim_removes_silence(self):
        x = np.concatenate([np.zeros(4410), np.sin(np.arange(4410) / 5), np.zeros(8820)])
        y = process_sfx.trim(x)
        self.assertLess(len(y), 4410 + 0.03 * A.SR)
        self.assertGreater(len(y), 4410)

    def test_normalise_never_clips(self):
        x = np.sin(np.arange(44100) / 3) * 0.01
        x[100] = 0.9  # one spike: the peak ceiling must win over the loudness target
        y, info = process_sfx.normalise(x, -6, -1.0)
        self.assertLessEqual(A.peak_db(y), -1.0 + 1e-6)
        self.assertTrue(info["peak_limited"])

    def test_fold_loop_is_seamless(self):
        n = 1000
        x = np.zeros(n + 300)
        x[n:] = 0.5  # tail that rings past the loop point
        y = process_sfx.fold_loop(x, n)
        self.assertEqual(len(y), n)
        self.assertAlmostEqual(y[0], 0.5)

    def test_licence_gate(self):
        ok = {"licence": {"verified": True, "commercial_use": True, "attribution_required": False}}
        self.assertIsNone(process_sfx.licence_problem(ok))
        self.assertIsNotNone(process_sfx.licence_problem(None))
        self.assertIsNotNone(process_sfx.licence_problem({"licence": {"verified": False, "commercial_use": True}}))
        self.assertIsNotNone(process_sfx.licence_problem(
            {"licence": {"verified": True, "commercial_use": True, "attribution_required": True}}))


class Manifest(unittest.TestCase):
    def test_manifest_matches_files(self):
        if not A.MANIFEST.exists():
            self.skipTest("run tools/audio/process_sfx.py first")
        manifest = json.loads(A.MANIFEST.read_text(encoding="utf-8"))
        ids = {a["id"] for a in manifest["assets"]}
        self.assertEqual(ids, {e["id"] for e in CATALOG})
        for a in manifest["assets"]:
            self.assertEqual(a["processing_status"], "processed", a["id"])
            path = ROOT / a["file_processed"]
            self.assertTrue(path.exists(), a["file_processed"])
            self.assertEqual(A.sha256_file(path), a["sha256"], a["id"])
            self.assertIsNone(a["roblox_asset_id"] if a["upload_status"] != "uploaded" else None)


if __name__ == "__main__":
    unittest.main()
