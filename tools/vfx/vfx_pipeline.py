"""VFX texture pipeline for Style My Bestie: generate, process, validate, write manifests.

    python tools/vfx/vfx_pipeline.py            # generate + process + validate + manifest
    python tools/vfx/vfx_pipeline.py --check    # validate only (exit 1 on problems)
    python tools/vfx/vfx_pipeline.py --set Heart=123 Star=456   # after uploading the textures

Textures are drawn procedurally from signed-distance shapes (no external art, no licence risk):
  assets/vfx/source/<name>.png      1024 px master, white shape + soft alpha
  assets/vfx/processed/<name>.png   256 px particle texture (power of two, white RGB, straight alpha)
  assets/vfx/manifests/vfx_manifest.json, upload_manifest.csv

White RGB everywhere means ParticleEmitter.Color tints them freely and there are no dark fringes.
Roblox only accepts uploaded image IDs, so each texture keeps a verified built-in fallback in
Config.Vfx.Textures until its upload ID is filled in.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import struct
import sys
import zlib
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
VFX = ROOT / "assets" / "vfx"
SOURCE, PROCESSED, MANIFESTS = VFX / "source", VFX / "processed", VFX / "manifests"
MANIFEST = MANIFESTS / "vfx_manifest.json"
UPLOAD_CSV = MANIFESTS / "upload_manifest.csv"
MASTER, OUT = 1024, 256

# Built-in particle textures confirmed to load in Roblox Studio (ContentProvider:PreloadAsync,
# with a fake path as a failing control) on 2026-10-24.
VERIFIED_BUILTIN_TEXTURES = [
    "rbxasset://textures/particles/sparkles_main.dds",
    "rbxasset://textures/particles/fire_main.dds",
    "rbxasset://textures/particles/smoke_main.dds",
    "rbxasset://textures/particles/fire_sparks_main.dds",
    "rbxasset://textures/particles/explosion01_core_main.dds",
    "rbxasset://textures/particles/explosion01_shockwave_main.dds",
    "rbxasset://textures/particles/explosion01_implosion_main.dds",
    "rbxasset://textures/particles/forcefield_glow_main.dds",
    "rbxasset://textures/particles/forcefield_vortex_main.dds",
]

LICENCE = {
    "name": "Original work (procedurally generated for this project)",
    "commercial_use": True,
    "attribution_required": False,
    "verified": True,
    "notes": "Drawn from mathematical shapes by tools/vfx/vfx_pipeline.py; no third-party material.",
}

# ------------------------------------------------------------------------------------------------
# Shapes: each returns coverage in [0, 1] on a grid of coordinates in [-1, 1].
# ------------------------------------------------------------------------------------------------


def grid(n: int) -> tuple[np.ndarray, np.ndarray]:
    c = (np.arange(n) + 0.5) / n * 2 - 1
    x, y = np.meshgrid(c, -c)  # y up
    return x, y


def soft(d: np.ndarray, width: float) -> np.ndarray:
    """Signed distance (negative inside) -> antialiased coverage."""
    return np.clip(0.5 - d / width, 0, 1)


def glow(x, y):
    r = np.hypot(x, y)
    return np.clip(np.exp(-(r / 0.42) ** 2) - np.exp(-(1 / 0.42) ** 2), 0, 1) / (1 - np.exp(-(1 / 0.42) ** 2))


def sparkle(x, y):
    """Four-point twinkle: two thin diamonds, a bright core and a soft halo."""
    ax, ay = np.abs(x), np.abs(y)
    arms = np.maximum(soft(ax * 1.05 + ay * 9 - 0.88, 0.02), soft(ay * 1.05 + ax * 9 - 0.88, 0.02))
    diag = np.maximum(soft((np.abs(x + y) * 0.7 + np.abs(x - y) * 9) / 1.414 - 0.45, 0.02),
                      soft((np.abs(x - y) * 0.7 + np.abs(x + y) * 9) / 1.414 - 0.45, 0.02)) * 0.6
    r = np.hypot(x, y)
    core = soft(r - 0.12, 0.04)
    halo = np.exp(-(r / 0.35) ** 2) * 0.55
    return np.clip(np.maximum.reduce([arms, diag, core, halo]), 0, 1)


def heart(x, y):
    # Implicit heart: (x^2 + y^2 - 1)^3 - x^2 y^3 <= 0, scaled and centred.
    s = 1.45
    hx, hy = x * s, (y + 0.12) * s
    f = (hx ** 2 + hy ** 2 - 1) ** 3 - hx ** 2 * hy ** 3
    inside = (f <= 0).astype(np.float64)
    # Soften by blurring the hard mask slightly (separable box blur, 3 passes ~ gaussian).
    k = max(1, x.shape[0] // 512)
    for _ in range(2):
        inside = (np.roll(inside, k, 0) + inside + np.roll(inside, -k, 0)) / 3
        inside = (np.roll(inside, k, 1) + inside + np.roll(inside, -k, 1)) / 3
    return np.clip(inside, 0, 1)


def star(x, y, points: int = 5, inner: float = 0.45, outer: float = 0.92):
    ang = np.arctan2(x, y)  # 0 = up
    r = np.hypot(x, y)
    sector = 2 * np.pi / points
    a = np.mod(ang + sector / 2, sector) - sector / 2  # angle from nearest point
    # Edge from the outer point (angle 0) to the inner vertex (angle sector/2), in polar form.
    p1 = np.array([0.0, outer])
    p2 = np.array([np.sin(sector / 2) * inner, np.cos(sector / 2) * inner])
    px, py = np.abs(r * np.sin(a)), r * np.cos(a)
    ex, ey = p2 - p1
    nx, ny = ey, -ex
    norm = np.hypot(nx, ny)
    d = ((px - p1[0]) * nx + (py - p1[1]) * ny) / norm
    return soft(-d, 0.02)  # d > 0 on the centre's side of the edge


def confetti(x, y):
    """Rounded paper strip (2.2 : 1), slightly tilted so spinning reads well."""
    t = np.radians(12)
    u, v = x * np.cos(t) - y * np.sin(t), x * np.sin(t) + y * np.cos(t)
    hw, hh, rad = 0.78, 0.36, 0.08
    qx, qy = np.abs(u) - (hw - rad), np.abs(v) - (hh - rad)
    d = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - rad
    return soft(d, 0.02)


TEXTURES = {
    "Sparkle": dict(fn=sparkle, fallback="rbxasset://textures/particles/sparkles_main.dds",
                    use="Sparkle bursts, READY sparkle, runway sparkle trail, rewards"),
    "Heart": dict(fn=heart, fallback="rbxasset://textures/particles/sparkles_main.dds",
                  use="Vote confirmation, audience reactions, heart rain"),
    "Star": dict(fn=star, fallback="rbxasset://textures/particles/sparkles_main.dds",
                 use="Star ratings, winner reveal, rank up"),
    "Confetti": dict(fn=confetti, fallback="rbxasset://textures/particles/sparkles_main.dds",
                     use="Confetti celebrations (podium, lobby moments)"),
    "Glow": dict(fn=glow, fallback="rbxasset://textures/particles/forcefield_glow_main.dds",
                 use="Soft radial glow: spotlight pools, auras, beam ends"),
}

# Every effect, the real handler that fires it, and how it was checked. "studio" = seen working in a
# Studio playtest through the MCP connection on 2026-10-24; "static" = code-reviewed + lint only.
EFFECTS = [
    ("Button press feedback", "existing: Kit.button / Components (scale tween)", "existing"),
    ("Player matching shuffle + partner reveal", "HUD.partnerReveal (Pairing phase)", "static (needs 2 players)"),
    ("Teleport transition", "HUD.phaseEffects: Lobby->Pairing, Results->Lobby", "studio"),
    ("Theme reveal burst + shimmer", "HUD.refreshRound (ThemeReveal)", "studio"),
    ("Reward collection (coins fly to counter)", "LobbyUI.coinPop (coins increase)", "static"),
    ("Rank-up star burst", "HUD.showRewards (rankUp)", "static"),
    ("Outfit completion sparkle", "Catalog READY button", "static (button press)"),
    ("Countdown warning pulse (last 10 s)", "HUD timer tick (Styling/Voting)", "static"),
    ("Time-up edge glow", "HUD.phaseEffects (leaving Styling)", "studio"),
    ("Runway spotlight sweep + fake volumetric beams", "Stage.runwayEntrance (RunwayEffect remote)", "studio"),
    ("Runway walker sparkle trail + light pool", "Stage.runwayEntrance", "studio"),
    ("VIP entrance: gold beams + chrome shimmer highlight", "Stage.runwayEntrance (isVip)", "static"),
    ("Camera flashes", "existing: Stage.flashLoop (respects Flashing effects)", "existing"),
    ("Vote confirmation", "VotingUI heart / StarsUI rating", "static (button press)"),
    ("Audience reaction burst", "ReactionsUI.float (Reaction remote)", "static"),
    ("Top-three podium highlights", "Stage.podiumReveal (Results)", "studio"),
    ("Winner reveal: light shaft, star burst, victory aura", "Stage.podiumReveal (1st place)", "studio"),
    ("Results row bursts + winner confetti on screen", "ResultsUI.refresh", "studio"),
    ("Podium confetti (world)", "existing: server Effects.burst", "existing"),
    ("Disco Mode lighting preset", "Moments.disco + Stage.setDisco", "static (needs a bought moment)"),
    ("Textured heart/confetti rain", "Moments.rain", "static"),
    ("Minigame bursts on the shared budget", "MinigameFx.burst -> Vfx.emit", "static"),
]

# ------------------------------------------------------------------------------------------------
# PNG I/O (stdlib only)
# ------------------------------------------------------------------------------------------------


def write_png(path: Path, rgba: np.ndarray) -> None:
    h, w, _ = rgba.shape
    raw = b"".join(b"\x00" + rgba[row].tobytes() for row in range(h))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def read_png(path: Path) -> np.ndarray:
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG"
    pos, idat, w, h = 8, b"", 0, 0
    color = depth = None
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        tag, body = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + length]
        if tag == b"IHDR":
            w, h, depth, color = struct.unpack(">IIBB", body[:10])
        elif tag == b"IDAT":
            idat += body
        pos += 12 + length
    if depth != 8 or color != 6:
        raise ValueError(f"{path.name}: expected 8-bit RGBA, got depth {depth} colour type {color}")
    raw = zlib.decompress(idat)
    stride = w * 4
    out = np.zeros((h, stride), dtype=np.uint8)
    prev = np.zeros(stride, dtype=np.int32)
    for row in range(h):
        f = raw[row * (stride + 1)]
        line = np.frombuffer(raw, dtype=np.uint8, count=stride, offset=row * (stride + 1) + 1).astype(np.int32)
        if f == 0:
            cur = line
        elif f == 2:
            cur = (line + prev) & 255
        else:  # filters 1, 3, 4 need per-pixel loops; our writer only uses filter 0
            cur = line.copy()
            for i in range(stride):
                a = cur[i - 4] if i >= 4 else 0
                b, c = prev[i], (prev[i - 4] if i >= 4 else 0)
                if f == 1:
                    cur[i] = (cur[i] + a) & 255
                elif f == 3:
                    cur[i] = (cur[i] + (a + b) // 2) & 255
                elif f == 4:
                    p = a + b - c
                    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                    pred = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                    cur[i] = (cur[i] + pred) & 255
        out[row] = cur
        prev = cur
    return out.reshape(h, w, 4)


def edge_fade(n: int) -> np.ndarray:
    """1 inside, falling to 0 over the outer 6% of the radius, so no shape can touch the border."""
    x, y = grid(n)
    return np.clip((1 - np.hypot(x, y)) / 0.06, 0, 1)


def to_rgba(coverage: np.ndarray) -> np.ndarray:
    a = np.round(np.clip(coverage, 0, 1) * 255).astype(np.uint8)
    rgba = np.full(coverage.shape + (4,), 255, dtype=np.uint8)
    rgba[..., 3] = a
    return rgba


def downsample(rgba: np.ndarray, size: int) -> np.ndarray:
    f = rgba.shape[0] // size
    a = rgba[..., 3].astype(np.float64).reshape(size, f, size, f).mean(axis=(1, 3))
    return to_rgba(a / 255)


# ------------------------------------------------------------------------------------------------
# Validation
# ------------------------------------------------------------------------------------------------


def check_texture(name: str, rgba: np.ndarray, expected: int) -> tuple[list[str], dict]:
    problems = []
    h, w, _ = rgba.shape
    a = rgba[..., 3].astype(np.float64) / 255
    stats = {
        "width": w,
        "height": h,
        "coverage": round(float(a.mean()), 4),
        "corner_alpha_max": int(max(rgba[0, 0, 3], rgba[0, -1, 3], rgba[-1, 0, 3], rgba[-1, -1, 3])),
        "border_alpha_max": int(max(rgba[0, :, 3].max(), rgba[-1, :, 3].max(), rgba[:, 0, 3].max(), rgba[:, -1, 3].max())),
        "rgb_white": bool((rgba[..., :3] == 255).all()),
    }
    if (w, h) != (expected, expected):
        problems.append(f"{name}: {w}x{h}, expected {expected}x{expected}")
    if w & (w - 1) or h & (h - 1):
        problems.append(f"{name}: not a power of two")
    if w > 1024 or h > 1024:
        problems.append(f"{name}: larger than 1024 px (Roblox downscales)")
    if stats["border_alpha_max"] > 8:
        problems.append(f"{name}: background not transparent at the edges (alpha {stats['border_alpha_max']})")
    if not 0.01 < stats["coverage"] < 0.8:
        problems.append(f"{name}: coverage {stats['coverage']} (empty or not a cut-out)")
    if not stats["rgb_white"]:
        problems.append(f"{name}: RGB is not pure white (tinting would be uneven)")
    return problems, stats


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build() -> None:
    for name, spec in TEXTURES.items():
        x, y = grid(MASTER)
        master = to_rgba(spec["fn"](x, y) * edge_fade(MASTER))
        write_png(SOURCE / f"{name.lower()}.png", master)
        write_png(PROCESSED / f"{name.lower()}.png", downsample(master, OUT))
        print(f"built {name}")


def validate_and_manifest(write: bool) -> int:
    previous = {}
    if MANIFEST.exists():
        previous = {t["name"]: t for t in json.loads(MANIFEST.read_text(encoding="utf-8"))["textures"]}
    records, problems, seen = [], [], {}
    for name, spec in TEXTURES.items():
        src, out = SOURCE / f"{name.lower()}.png", PROCESSED / f"{name.lower()}.png"
        if not src.exists() or not out.exists():
            problems.append(f"{name}: missing file (run without --check)")
            continue
        src_problems, src_stats = check_texture(name + " (source)", read_png(src), MASTER)
        out_problems, out_stats = check_texture(name, read_png(out), OUT)
        problems += src_problems + out_problems
        digest = sha(out)
        if digest in seen:
            problems.append(f"{name}: duplicate of {seen[digest]}")
        seen[digest] = name
        prev = previous.get(name, {})
        records.append({
            "name": name,
            "config_key": f"Config.Vfx.Textures.{name}",
            "use": spec["use"],
            "file_source": src.relative_to(ROOT).as_posix(),
            "file_processed": out.relative_to(ROOT).as_posix(),
            "source": {"type": "procedural", "tool": "tools/vfx/vfx_pipeline.py", "shape": spec["fn"].__name__},
            "licence": LICENCE,
            "processing": ["1024 px master drawn from a signed-distance shape",
                           "box-downsampled to 256 px", "RGB forced to white, straight alpha"],
            "checks": out_stats,
            "sha256": digest,
            "builtin_fallback": spec["fallback"],
            "roblox_asset_id": prev.get("roblox_asset_id"),
            "upload_status": prev.get("upload_status") or "pending_manual_upload",
        })
    if write:
        MANIFESTS.mkdir(parents=True, exist_ok=True)
        manifest = {
            "schema_version": 1,
            "game": "Style My Bestie",
            "generated_by": "tools/vfx/vfx_pipeline.py",
            "config": "src/shared/Config.luau (Config.Vfx.Textures)",
            "textures": records,
            "verified_builtin_textures": VERIFIED_BUILTIN_TEXTURES,
            "effects": [{"effect": e, "handler": h, "verification": v} for e, h, v in EFFECTS],
            "problems": problems,
        }
        MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        with UPLOAD_CSV.open("w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(["name", "file", "asset_type", "config_key", "roblox_asset_id"])
            for r in records:
                w.writerow([r["name"], r["file_processed"], "Decal/Image", r["config_key"], r["roblox_asset_id"] or ""])
    problems += check_config()
    for p in problems:
        print("PROBLEM:", p)
    print(f"{len(records)} textures checked: {'OK' if not problems else 'FAILED'}")
    return 1 if problems else 0


def check_config() -> list[str]:
    """Config.Vfx must list exactly these textures, with verified fallbacks and real numeric IDs;
    every module that requires Vfx must resolve to src/client/Vfx.luau."""
    import re

    problems = []
    text = (ROOT / "src" / "shared" / "Config.luau").read_text(encoding="utf-8")
    block = text[text.index("Config.Vfx = {"):]
    textures = re.search(r"Textures = \{(.*?)\}", block, re.S).group(1)
    fallbacks = re.search(r"Fallbacks = \{(.*?)\}", block, re.S).group(1)
    ids = dict(re.findall(r"(\w+) = (\d+),", textures))
    falls = dict(re.findall(r'(\w+) = "([^"]+)"', fallbacks))
    if set(ids) != set(TEXTURES):
        problems.append(f"Config.Vfx.Textures keys {sorted(ids)} != {sorted(TEXTURES)}")
    for name, path in falls.items():
        if path not in VERIFIED_BUILTIN_TEXTURES:
            problems.append(f"Config.Vfx.Fallbacks.{name} = {path} is not a verified built-in texture")
    manifest_ids = {}
    if MANIFEST.exists():
        manifest_ids = {t["name"]: t.get("roblox_asset_id") for t in json.loads(MANIFEST.read_text("utf-8"))["textures"]}
    for name, value in ids.items():
        if value != "0" and int(value) != (manifest_ids.get(name) or -1):
            problems.append(f"Config.Vfx.Textures.{name} = {value} is not recorded as uploaded in the manifest")
    client = ROOT / "src" / "client"
    for path in (ROOT / "src").rglob("*.luau"):
        for m in re.finditer(r"require\((script(?:\.Parent)+)\.Vfx\)", path.read_text(encoding="utf-8")):
            ups = m.group(1).count(".Parent")
            target = path.parent  # script.Parent of a module is the folder it sits in
            for _ in range(ups - 1):
                target = target.parent
            if (target / "Vfx.luau").resolve() != (client / "Vfx.luau").resolve():
                problems.append(f"{path.relative_to(ROOT)}: {m.group(0)} does not resolve to src/client/Vfx.luau")
    return problems


def set_ids(pairs: list[str], config: Path | None = None, manifest_path: Path | None = None) -> int:
    """Record uploaded image IDs (Name=ID) in the manifest and Config.Vfx.Textures."""
    import re

    config = config or ROOT / "src" / "shared" / "Config.luau"
    manifest_path = manifest_path or MANIFEST
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    by_name = {t["name"]: t for t in manifest["textures"]}
    with config.open(encoding="utf-8", newline="") as f:
        text = f.read()
    start = text.index("Config.Vfx = {")
    end = text.index("Fallbacks = {", start)
    block = text[start:end]
    for pair in pairs:
        name, _, raw = pair.partition("=")
        raw = raw.strip().removeprefix("rbxassetid://")
        if name not in by_name or not raw.isdigit() or int(raw) <= 0:
            print(f"bad --set {pair!r}: use Name=AssetId with Name in {sorted(by_name)}")
            return 1
        block, n = re.subn(rf"(\t\t{name} = )\d+,", rf"\g<1>{int(raw)},", block)
        if n != 1:
            print(f"Config.Vfx.Textures.{name} not found")
            return 1
        by_name[name]["roblox_asset_id"] = int(raw)
        by_name[name]["upload_status"] = "uploaded"
        print(f"{name} -> {raw}")
    with config.open("w", encoding="utf-8", newline="") as f:
        f.write(text[:start] + block + text[end:])
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--set", nargs="*", metavar="NAME=ASSET_ID", help="record uploaded texture IDs")
    args = ap.parse_args()
    if args.set:
        if set_ids(args.set):
            return 1
        return validate_and_manifest(write=True)
    if not args.check:
        build()
    return validate_and_manifest(write=not args.check)


if __name__ == "__main__":
    raise SystemExit(main())
