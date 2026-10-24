"""Check the audio pipeline and the game's sound wiring. Exit code 1 on any error.

    python tools/audio/validate_sfx.py           # prints the report
    python tools/audio/validate_sfx.py --json reports/sfx_validation.json

Checks:
  * every catalog file is processed, exists, matches its recorded hash and has a verified licence
  * durations, peaks and loop seams are within limits; duplicates are flagged
  * every sound key the code plays exists in Config.Sounds (and every Config key is played)
  * every Config.Sounds value is silent, a Studio-verified built-in, a Studio-verified store ID,
    or an ID recorded as uploaded in the manifest (no unverified IDs)
  * no sound IDs are hard-coded outside Config.Sounds
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audiolib as A  # noqa: E402
from sfx_catalog import CATALOG, KEEP_BUILTIN  # noqa: E402

SRC = A.ROOT / "src"
PLAY_PATTERNS = [
    re.compile(r'Kit\.playSound\(\s*"(\w+)"'),
    re.compile(r'Config\.soundId\(\s*"(\w+)"\s*\)'),
    re.compile(r'(?:then|else)\s+"(\w+)"'),  # Kit.playSound(if a then "X" else "Y")
]


def played_keys() -> dict[str, list[str]]:
    used: dict[str, list[str]] = {}
    for path in SRC.rglob("*.luau"):
        rel = path.relative_to(A.ROOT).as_posix()
        for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if "playSound" in line or "soundId" in line:
                for pat in PLAY_PATTERNS:
                    for m in pat.finditer(line):
                        for key in m.groups():
                            used.setdefault(key, []).append(f"{rel}:{n}")
        if rel.endswith("Minigames/Arena.luau"):  # Config.soundId("Minigame" .. name) over a name list
            text = path.read_text(encoding="utf-8")
            block = re.search(r"for _, name in\s*\{(.*?)\}", text, re.S)
            for name in re.findall(r'"(\w+)"', block.group(1) if block else ""):
                used.setdefault("Minigame" + name, []).append(rel)
    return used


def hardcoded_ids() -> list[str]:
    hits = []
    pat = re.compile(r'(rbxasset://sounds/|SoundId\s*=\s*"rbxassetid://\d)')
    for path in SRC.rglob("*.luau"):
        rel = path.relative_to(A.ROOT).as_posix()
        if rel == "src/shared/Config.luau":
            continue
        for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if pat.search(line):
                hits.append(f"{rel}:{n}: {line.strip()}")
    return hits


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json")
    args = ap.parse_args()
    errors: list[str] = []
    warnings: list[str] = []

    manifest = json.loads(A.MANIFEST.read_text(encoding="utf-8"))
    assets = {a["id"]: a for a in manifest["assets"]}
    for entry in CATALOG:
        a = assets.get(entry["id"])
        if not a:
            errors.append(f"{entry['id']}: missing from manifest (run process_sfx.py)")
            continue
        if a["processing_status"] != "processed":
            errors.append(f"{a['id']}: {a['processing_status']} {a.get('rejection_reason', '')}")
            continue
        path = A.ROOT / a["file_processed"]
        if not path.exists():
            errors.append(f"{a['id']}: processed file missing ({a['file_processed']})")
            continue
        if A.sha256_file(path) != a["sha256"]:
            errors.append(f"{a['id']}: file changed since the manifest was written (re-run process_sfx.py)")
        if not (A.ROOT / a["file_source"]).exists():
            errors.append(f"{a['id']}: original source missing ({a['file_source']})")
        lic = a.get("licence") or {}
        if not (lic.get("verified") and lic.get("commercial_use")):
            errors.append(f"{a['id']}: licence not verified for commercial use")
        if a["peak_dbfs"] > -0.1:
            errors.append(f"{a['id']}: peak {a['peak_dbfs']} dBFS (clipping)")
        if a["category"] not in manifest["categories"] or f"/{a['category']}/" not in a["file_processed"]:
            errors.append(f"{a['id']}: not filed under its category folder")
        for flag in a.get("flags", []):
            (errors if flag.startswith(("duplicate_of", "loop_seam", "exceeds", "clipping")) else warnings).append(
                f"{a['id']}: {flag}")
        if a["loop"] and not (a.get("loop_check") or {}).get("seamless"):
            errors.append(f"{a['id']}: loop seam not seamless")
    on_disk = {p.relative_to(A.ROOT).as_posix() for p in A.PROCESSED.rglob("*") if p.is_file()}
    listed = {a.get("file_processed") for a in assets.values()}
    for stray in sorted(on_disk - listed):
        warnings.append(f"unlisted processed file: {stray}")

    sounds = A.config_sounds()
    used = played_keys()
    uploaded = {a["roblox_asset_id"] for a in assets.values() if a.get("roblox_asset_id")}
    for key, where in sorted(used.items()):
        if key not in sounds:
            errors.append(f"code plays {key!r} but Config.Sounds has no such key ({where[0]})")
    unused = sorted(k for k in sounds if k not in used and k not in ("RunwayMusic", "LobbyMusic"))
    for key in unused:
        warnings.append(f"Config.Sounds.{key} is never played")
    statuses = {}
    for key, info in sounds.items():
        value = info["value"]
        status = A.value_status(value)
        if status == "uploaded_or_unverified_id":
            status = "uploaded" if value in uploaded else "UNVERIFIED"
        statuses[key] = status
        if status in ("UNVERIFIED", "unverified_builtin", "unknown"):
            errors.append(f"Config.Sounds.{key} = {info['raw']} is not a verified sound")
        prepared = any(key in a["config_keys"] for a in assets.values())
        if not prepared and key not in KEEP_BUILTIN and status != "verified_store_audio":
            warnings.append(f"Config.Sounds.{key} has no prepared file")
    silent = sorted(k for k, s in statuses.items() if s == "silent")
    for hit in hardcoded_ids():
        errors.append(f"hard-coded sound outside Config.Sounds: {hit}")

    # Shared values: several events playing the very same sound.
    shared: dict[str, list[str]] = {}
    for key, info in sounds.items():
        if info["value"] != 0:
            shared.setdefault(str(info["value"]), []).append(key)
    shared = {v: ks for v, ks in shared.items() if len(ks) > 1}

    report = {
        "errors": errors,
        "warnings": warnings,
        "silent_keys_waiting_for_upload": silent,
        "key_status": statuses,
        "played_keys": {k: v for k, v in sorted(used.items())},
        "unused_keys": unused,
        "shared_sounds": shared,
        "files_checked": len(assets),
    }
    if args.json:
        out = A.ROOT / args.json
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    for w in warnings:
        print("WARN ", w)
    for e in errors:
        print("ERROR", e)
    print(f"\n{len(assets)} files, {len(sounds)} Config keys, {len(silent)} silent until upload: {', '.join(silent)}")
    print("FAILED" if errors else "OK")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
