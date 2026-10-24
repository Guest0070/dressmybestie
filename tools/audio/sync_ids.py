"""Write uploaded Roblox audio asset IDs from the manifest into Config.Sounds.

    python tools/audio/sync_ids.py --set ui_ready=1234567890 rw_coins=2345678901
    python tools/audio/sync_ids.py                 # apply every recorded ID (dry run: --dry-run)
    python tools/audio/sync_ids.py --include-replacements

--set records IDs (from Studio's Asset Manager or upload_opencloud.py) in sfx_manifest.json.
By default an ID only goes into keys that are silent today (0); keys that already play a working
sound keep it unless --include-replacements is given. Nothing is ever invented: only IDs you
recorded are written.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audiolib as A  # noqa: E402


def parse_asset_id(text: str) -> int:
    text = text.strip().removeprefix("rbxassetid://")
    if not text.isdigit() or int(text) <= 0:
        raise ValueError(f"not a Roblox asset ID: {text!r}")
    return int(text)


def apply_ids(config_text: str, wanted: dict[str, int]) -> tuple[str, list[str]]:
    """Return config_text with Config.Sounds keys set to the given IDs, and a change log."""
    sounds = A.config_sounds(config_text)
    lines = config_text.split("\n")
    log = []
    for key, asset_id in wanted.items():
        info = sounds.get(key)
        if info is None:
            log.append(f"skip {key}: not in Config.Sounds")
            continue
        line = lines[info["line"]]
        m = A.KEY_LINE.match(line.rstrip("\r"))
        assert m, line
        crlf = "\r" if line.endswith("\r") else ""
        if info["value"] == asset_id:
            continue
        lines[info["line"]] = f"{m.group(1)}{key} = {asset_id},{m.group(4)}{crlf}"
        log.append(f"{key}: {info['raw']} -> {asset_id}")
    return "\n".join(lines), log


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--set", nargs="*", default=[], metavar="FILE_ID=ASSET_ID")
    ap.add_argument("--include-replacements", action="store_true",
                    help="also replace keys that already play a working sound")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    manifest = json.loads(A.MANIFEST.read_text(encoding="utf-8"))
    assets = {a["id"]: a for a in manifest["assets"]}
    for pair in args.set:
        file_id, _, raw = pair.partition("=")
        if file_id not in assets:
            print(f"unknown file id {file_id!r}")
            return 1
        assets[file_id]["roblox_asset_id"] = parse_asset_id(raw)
        assets[file_id]["upload_status"] = "uploaded"

    with A.CONFIG.open(encoding="utf-8", newline="") as f:  # keep the file's line endings
        text = f.read()
    sounds = A.config_sounds(text)
    wanted: dict[str, int] = {}
    uploaded_ids = {a["roblox_asset_id"] for a in assets.values() if a.get("roblox_asset_id")}
    for a in assets.values():
        if not a.get("roblox_asset_id"):
            continue
        for key in a["config_keys"]:
            current = sounds.get(key, {}).get("value")
            replaceable = current == 0 or current in uploaded_ids or args.include_replacements
            if replaceable:
                wanted[key] = a["roblox_asset_id"]
    new_text, log = apply_ids(text, wanted)
    for line in log:
        print(line)
    if not log:
        print("Config.Sounds already up to date")
    if args.dry_run:
        return 0
    if new_text != text:
        with A.CONFIG.open("w", encoding="utf-8", newline="") as f:
            f.write(new_text)
    A.MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
