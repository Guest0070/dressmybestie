"""Tests for the VFX texture pipeline (tools/vfx). Run:  python -m unittest discover -s tests -p "test_*.py" """

import json
import re
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "vfx"))

import vfx_pipeline as V  # noqa: E402


class Png(unittest.TestCase):
    def test_round_trip(self):
        rgba = np.zeros((8, 8, 4), dtype=np.uint8)
        rgba[2:6, 2:6] = [255, 255, 255, 200]
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "t.png"
            V.write_png(path, rgba)
            self.assertTrue((V.read_png(path) == rgba).all())


class Checks(unittest.TestCase):
    def shape(self, fn):
        x, y = V.grid(256)
        return V.to_rgba(fn(x, y) * V.edge_fade(256))

    def test_every_texture_passes(self):
        for name, spec in V.TEXTURES.items():
            problems, stats = V.check_texture(name, self.shape(spec["fn"]), 256)
            self.assertEqual(problems, [], name)
            self.assertEqual(stats["border_alpha_max"], 0, name)

    def test_opaque_background_is_rejected(self):
        solid = V.to_rgba(np.ones((256, 256)))
        problems, _ = V.check_texture("solid", solid, 256)
        self.assertTrue(any("transparent" in p for p in problems))

    def test_wrong_size_and_tint_are_rejected(self):
        img = self.shape(V.glow)[:200, :200].copy()
        img[100, 100, 0] = 10  # not white
        problems, _ = V.check_texture("bad", img, 256)
        self.assertTrue(any("expected 256x256" in p for p in problems))
        self.assertTrue(any("power of two" in p for p in problems))
        self.assertTrue(any("white" in p for p in problems))

    def test_shapes_are_distinct(self):
        prints = {name: self.shape(spec["fn"])[..., 3].astype(float) for name, spec in V.TEXTURES.items()}
        names = list(prints)
        for i, a in enumerate(names):
            for b in names[i + 1:]:
                diff = np.abs(prints[a] - prints[b]).mean()
                self.assertGreater(diff, 5, f"{a} vs {b} look the same")


class SetIds(unittest.TestCase):
    def test_writes_config_and_manifest_copies(self):
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp) / "Config.luau"
            manifest = Path(tmp) / "vfx_manifest.json"
            config.write_bytes((ROOT / "src" / "shared" / "Config.luau").read_bytes())
            manifest.write_bytes(V.MANIFEST.read_bytes())
            star_before = re.search(r"		Star = \d+,", config.read_text(encoding="utf-8")).group(0)
            self.assertEqual(V.set_ids(["Heart=123456"], config, manifest), 0)
            text = config.read_text(encoding="utf-8")
            self.assertIn("		Heart = 123456,", text)
            self.assertIn(star_before, text)  # other keys untouched
            entry = next(t for t in json.loads(manifest.read_text())["textures"] if t["name"] == "Heart")
            self.assertEqual(entry["roblox_asset_id"], 123456)
            self.assertEqual(V.set_ids(["Nope=1"], config, manifest), 1)
            self.assertEqual(V.set_ids(["Star=abc"], config, manifest), 1)


class Repo(unittest.TestCase):
    def test_config_and_require_paths(self):
        self.assertEqual(V.check_config(), [])

    def test_manifest_matches_files(self):
        manifest = json.loads(V.MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual({t["name"] for t in manifest["textures"]}, set(V.TEXTURES))
        self.assertEqual(manifest["problems"], [])
        for t in manifest["textures"]:
            path = ROOT / t["file_processed"]
            self.assertEqual(V.sha(path), t["sha256"], t["name"])
            self.assertIn(t["builtin_fallback"], V.VERIFIED_BUILTIN_TEXTURES)
            self.assertTrue(t["licence"]["commercial_use"])


if __name__ == "__main__":
    unittest.main()
