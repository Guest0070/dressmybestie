"""Batch-process every source sound into upload-ready files and write the manifest.

    python tools/audio/process_sfx.py

For each entry in sfx_catalog.py:
  1. find its source (assets/audio/source/generated/<id>.wav, or any audio file named <id>.* in
     assets/audio/source/external/) and its <id>.json licence sidecar; reject unclear licences
  2. decode with ffmpeg (any format) to mono 44.1 kHz
  3. music: fold the tail rendered past the loop point back onto the start (seamless loop);
     everything else: trim leading/trailing silence and add a short fade-out
  4. normalise to the entry's RMS target, never above the peak ceiling (no clipping)
  5. encode OGG Vorbis into assets/audio/processed/<Category>/<id>.ogg (sources are never touched)
  6. decode the result again and measure it; flag bad durations, clipping, duplicates, loop seams
Then writes assets/audio/sfx_manifest.json and assets/audio/upload_manifest.csv.
Uploaded asset IDs already recorded in the manifest are kept.
"""

from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audiolib as A  # noqa: E402
from sfx_catalog import CATALOG, KEEP_BUILTIN  # noqa: E402

AUDIO_EXTS = (".wav", ".ogg", ".mp3", ".flac")
ROBLOX_MAX_S = 420  # 7 minutes (Open Cloud / Studio audio limit)
PEAK_CEILING = {"default": -1.0, "loop": -1.5}

# Candidates looked at and turned down (Creator Store search through Studio, 2026-10-24).
REJECTED = [
    {
        "candidate": "User-uploaded Creator Store sound effects (coin, level-up, cash-register searches)",
        "examples": ["93529351909119", "108161825312558", "101396758527961", "86311747395907"],
        "reason": "Uploaded by individual users with no stated licence; several name another game "
                  "('From CSGO', 'cod zombies') or a third-party source needing credit ('credits to LilMati on "
                  "freesound'), or say 'for personal use'. Rights unclear for a monetised experience.",
    },
    {
        "candidate": "DistrokidOfficial music (e.g. 113679381925802 'Runway Model (Fashion Walk)')",
        "examples": ["113679381925802", "114469753084061"],
        "reason": "Not rejected on licence grounds (DistroKid tracks are distributed to Roblox for use in "
                  "experiences), but APMOfficial tracks were preferred: Roblox's long-standing licensed "
                  "library with full metadata. Kept as alternatives.",
        "status": "alternative",
    },
]


def find_source(entry_id: str) -> tuple[Path | None, Path | None]:
    gen = A.SOURCE / "generated" / f"{entry_id}.wav"
    if gen.exists():
        return gen, gen.with_suffix(".json")
    ext_dir = A.SOURCE / "external"
    for ext in AUDIO_EXTS:
        f = ext_dir / f"{entry_id}{ext}"
        if f.exists():
            return f, f.with_suffix(".json")
    return None, None


def licence_problem(sidecar: dict | None) -> str | None:
    if sidecar is None:
        return "no licence sidecar (<id>.json) next to the source file"
    lic = sidecar.get("licence") or {}
    if not lic.get("verified"):
        return "licence not verified"
    if not lic.get("commercial_use"):
        return "licence does not allow commercial use"
    if lic.get("attribution_required") and not lic.get("attribution_text"):
        return "licence needs attribution but no attribution_text is recorded"
    if lic.get("restrictions"):
        return f"licence restrictions: {lic['restrictions']}"
    return None


def trim(x: np.ndarray, threshold_db: float = -60) -> np.ndarray:
    peak = np.max(np.abs(x)) or 1.0
    thr = peak * 10 ** (threshold_db / 20)
    loud = np.nonzero(np.abs(x) > thr)[0]
    if not len(loud):
        return x
    a = max(0, loud[0] - int(0.002 * A.SR))
    b = min(len(x), loud[-1] + int(0.02 * A.SR))
    y = x[a:b].copy()
    fade = min(len(y), int(0.005 * A.SR))
    y[-fade:] *= np.linspace(1, 0, fade)
    return y


def fold_loop(x: np.ndarray, loop_samples: int) -> np.ndarray:
    y = x[:loop_samples].copy()
    tail = x[loop_samples:]
    while len(tail):
        part = tail[:loop_samples]
        y[: len(part)] += part
        tail = tail[loop_samples:]
    return y


def normalise(x: np.ndarray, target_rms: float, ceiling: float) -> tuple[np.ndarray, dict]:
    rms, peak = A.rms_db(x), A.peak_db(x)
    gain = min(target_rms - rms, ceiling - peak)
    y = x * 10 ** (gain / 20)
    return y, {"gain_db": round(gain, 2), "peak_limited": bool(ceiling - peak < target_rms - rms)}


def upload_priority(keys: list[str], sounds: dict) -> tuple[int, str]:
    statuses = [A.value_status(sounds[k]["value"]) if k in sounds else "missing_key" for k in keys]
    if any(s in ("silent", "missing_key") for s in statuses):
        return 1, "fills an event that is silent today"
    if all(s == "verified_store_audio" for s in statuses):
        return 3, "fallback only: a verified Creator Store track already fills this"
    return 2, "optional replacement for a working built-in sound (more distinct per event)"


def main() -> int:
    sounds = A.config_sounds()
    previous = {}
    if A.MANIFEST.exists():
        for a in json.loads(A.MANIFEST.read_text(encoding="utf-8")).get("assets", []):
            previous[a["id"]] = a
    assets, problems = [], []
    prints: list[tuple[str, np.ndarray]] = []
    hashes: dict[str, str] = {}

    for entry in CATALOG:
        eid = entry["id"]
        rel_out = Path("assets/audio/processed") / entry["category"] / f"{eid}.ogg"
        record = {
            "id": eid,
            "category": entry["category"],
            "config_keys": entry["keys"],
            "gameplay_events": entry["events"],
            "loop": entry["loop"],
            "max_duration_s": entry["max_s"],
            "target_rms_dbfs": entry["rms_db"],
        }
        src, side = find_source(eid)
        sidecar = json.loads(side.read_text(encoding="utf-8")) if side and side.exists() else None
        record["file_source"] = src.relative_to(A.ROOT).as_posix() if src else None
        record["source"] = (sidecar or {}).get("source")
        record["licence"] = (sidecar or {}).get("licence")
        if src is None:
            record["processing_status"] = "missing_source"
            problems.append(f"{eid}: no source file")
            assets.append(record)
            continue
        bad = licence_problem(sidecar)
        if bad:
            record["processing_status"] = "rejected_licence"
            record["rejection_reason"] = bad
            problems.append(f"{eid}: {bad}")
            assets.append(record)
            continue

        x = A.decode(src)
        steps = ["decoded mono 44.1 kHz"]
        if entry["loop"] and sidecar.get("loop_samples"):
            x = fold_loop(x, int(sidecar["loop_samples"]))
            steps.append("loop tail folded onto start")
        else:
            before = len(x)
            x = trim(x)
            steps.append(f"silence trimmed ({(before - len(x)) / A.SR * 1000:.0f} ms)")
        ceiling = PEAK_CEILING["loop" if entry["loop"] else "default"]
        x, norm = normalise(x, entry["rms_db"], ceiling)
        steps.append(f"normalised {norm['gain_db']:+.1f} dB" + (" (peak-limited)" if norm["peak_limited"] else ""))
        out = A.ROOT / rel_out
        A.encode_ogg(x, out)
        steps.append("encoded OGG Vorbis q6")

        y = A.decode(out)
        duration = len(y) / A.SR
        flags = []
        if duration > entry["max_s"]:
            flags.append(f"too_long (> {entry['max_s']} s)")
        if duration < 0.03:
            flags.append("too_short")
        if duration > ROBLOX_MAX_S:
            flags.append("exceeds_roblox_7_minute_limit")
        peak = A.peak_db(y)
        if peak > -0.1:
            flags.append("clipping_risk")
        loop_info = None
        if entry["loop"]:
            # OGG decoders add priming silence/padding; measure the seam on the pre-encode buffer too.
            # A click at the seam = the wrap-around step is far bigger than normal sample-to-sample steps.
            jump = float(abs(x[-1] - x[0]))
            typical = float(np.percentile(np.abs(np.diff(x)), 99))
            loop_info = {"seam_sample_jump": round(jump, 4), "typical_step_p99": round(typical, 4),
                         "seamless": jump <= max(0.02, 2 * typical)}
            if not loop_info["seamless"]:
                flags.append("loop_seam_audible")

        digest = A.sha256_file(out)
        dup = hashes.get(digest)
        fp = A.fingerprint(y)
        near = next((other for other, ofp in prints if len(ofp) == len(fp) and float(fp @ ofp) > 0.995), None)
        if dup or near:
            flags.append(f"duplicate_of {dup or near}")
        hashes[digest] = eid
        prints.append((eid, fp))

        prio, why = upload_priority(entry["keys"], sounds)
        prev = previous.get(eid, {})
        record.update({
            "file_processed": rel_out.as_posix(),
            "processing_status": "processed",
            "processing_steps": steps,
            "duration_s": round(duration, 3),
            "sample_rate": A.SR,
            "channels": 1,
            "format": "ogg/vorbis",
            "peak_dbfs": round(peak, 2),
            "rms_dbfs": round(A.rms_db(y), 2),
            "loop_check": loop_info,
            "flags": flags,
            "sha256": digest,
            "upload_priority": prio,
            "upload_priority_reason": why,
            "roblox_asset_id": prev.get("roblox_asset_id"),
            "upload_status": prev.get("upload_status") or "pending_manual_upload",
        })
        assets.append(record)
        print(f"{eid:18} {duration:6.2f}s peak {peak:6.1f} rms {record['rms_dbfs']:6.1f}  P{prio} {' '.join(flags)}")

    # Config keys and what fills each one.
    by_key = {k: a["id"] for a in assets for k in a["config_keys"]}
    keys = {}
    store_audio = []
    for key, info in sounds.items():
        value = info["value"]
        status = A.value_status(value)
        keys[key] = {"current_value": value, "current_status": status, "prepared_file": by_key.get(key)}
        if key in KEEP_BUILTIN:
            keys[key]["note"] = "keeps its working built-in sound; no file prepared"
        if status == "verified_store_audio":
            meta = A.VERIFIED_STORE_AUDIO[value]
            store_audio.append({"config_key": key, "roblox_asset_id": value, **meta,
                                "source": {"type": "roblox_creator_store", "url": meta["url"]},
                                "licence": A.STORE_LICENCE, "verification": "loaded in Roblox Studio (IsLoaded, TimeLength)"})
        if status == "verified_builtin":
            keys[key]["builtin_duration_s"] = A.VERIFIED_BUILTINS[value]
    for key in by_key:
        if key not in sounds:
            problems.append(f"catalog key {key} is not in Config.Sounds")

    manifest = {
        "schema_version": 1,
        "game": "Style My Bestie",
        "generated_by": "tools/audio/process_sfx.py",
        "config_file": "src/shared/Config.luau (Config.Sounds)",
        "processed_root": "assets/audio/processed",
        "categories": ["UI", "Gameplay", "Runway", "Results", "Rewards", "Music"],
        "assets": assets,
        "store_audio": store_audio,
        "config_keys": keys,
        "rejected_candidates": REJECTED,
        "summary": {
            "files": len(assets),
            "processed": sum(a["processing_status"] == "processed" for a in assets),
            "flagged": sorted(a["id"] for a in assets if a.get("flags")),
            "upload_priority_counts": {p: sum(a.get("upload_priority") == p for a in assets) for p in (1, 2, 3)},
            "uploaded": sum(bool(a.get("roblox_asset_id")) for a in assets),
            "problems": problems,
        },
    }
    A.MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    with A.UPLOAD_CSV.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["upload_priority", "id", "file", "display_name", "description", "config_keys", "duration_s",
                    "roblox_asset_id"])
        for a in sorted((a for a in assets if a["processing_status"] == "processed"),
                        key=lambda a: (a["upload_priority"], a["category"], a["id"])):
            w.writerow([a["upload_priority"], a["id"], a["file_processed"],
                        f"SMB {a['category']} {a['id']}", "; ".join(a["gameplay_events"])[:900],
                        " ".join(a["config_keys"]), a["duration_s"], a.get("roblox_asset_id") or ""])
    print(f"\nmanifest: {A.MANIFEST.relative_to(A.ROOT)}  upload list: {A.UPLOAD_CSV.relative_to(A.ROOT)}")
    for p in problems:
        print("PROBLEM:", p)
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
