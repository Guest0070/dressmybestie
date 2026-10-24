"""Shared helpers for the audio pipeline: paths, Config.Sounds parsing, ffmpeg I/O, measurements."""

from __future__ import annotations

import hashlib
import re
import shutil
import subprocess
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / "src" / "shared" / "Config.luau"
AUDIO = ROOT / "assets" / "audio"
SOURCE = AUDIO / "source"
PROCESSED = AUDIO / "processed"
MANIFEST = AUDIO / "sfx_manifest.json"
UPLOAD_CSV = AUDIO / "upload_manifest.csv"
SR = 44100

# rbxasset://sounds/ paths confirmed to load in Roblox Studio (Sound.IsLoaded, TimeLength > 0) on
# 2026-10-24 through the Studio MCP connection. A path not listed here is "unverified".
VERIFIED_BUILTINS = {
    "rbxasset://sounds/clickfast.wav": 0.288,
    "rbxasset://sounds/switch.wav": 0.235,
    "rbxasset://sounds/snap.mp3": 0.418,
    "rbxasset://sounds/victory.wav": 1.306,
    "rbxasset://sounds/Launching rocket.wav": 1.817,
    "rbxasset://sounds/bass.wav": 1.008,
    "rbxasset://sounds/glassbreak.wav": 1.578,
    "rbxasset://sounds/uuhhh.mp3": 0.332,
    "rbxasset://sounds/hit.wav": 0.836,
    "rbxasset://sounds/swordslash.wav": 0.653,
    "rbxasset://sounds/flashbulb.wav": 0.360,
    "rbxasset://sounds/impact_explosion_03.mp3": 2.586,
    "rbxasset://sounds/impact_water.mp3": 2.377,
}

# Creator Store audio IDs confirmed to load in Studio, with their store metadata (same check).
VERIFIED_STORE_AUDIO = {
    1846743916: {
        "name": "It's Party Time (B)",
        "creator": "APMOfficial",
        "duration_s": 141.5,
        "url": "https://create.roblox.com/store/asset/1846743916",
        "notes": "Instrumental kids' party groove, pop. Sonoton Music, album Beats For Kids. Courtesy of APM Music.",
    },
    1839940316: {
        "name": "Jump Up",
        "creator": "APMOfficial",
        "duration_s": 60.4,
        "url": "https://create.roblox.com/store/asset/1839940316",
        "notes": "Disco-infused electro synth bed, 60 s version. Juice Music, album Upbeat Beds. Courtesy of APM Music.",
    },
}

STORE_LICENCE = {
    "name": "Roblox Creator Store: APM Music partner library",
    "commercial_use": True,
    "attribution_required": False,
    "verified": True,
    "notes": "Published free on the Creator Store by APMOfficial, Roblox's licensed music partner, for use in "
             "Roblox experiences (including monetised ones). Licence covers use inside Roblox only: do not "
             "reuse the track in trailers or videos off the platform without your own licence.",
}

KEY_LINE = re.compile(r"^(\s*)([A-Za-z_][A-Za-z0-9_]*) = ([^,]+),(.*)$")


def config_sounds(text: str | None = None) -> dict[str, dict]:
    """Parse the Config.Sounds block: key -> {value, line (0-based), raw}."""
    lines = (text if text is not None else CONFIG.read_text(encoding="utf-8")).splitlines()
    start = next(i for i, line in enumerate(lines) if line.startswith("Config.Sounds = {"))
    out: dict[str, dict] = {}
    for i in range(start + 1, len(lines)):
        line = lines[i]
        if line.startswith("}"):
            break
        m = KEY_LINE.match(line)
        if not m:
            continue
        raw = m.group(3).strip()
        if raw.startswith('"'):
            value: object = raw.strip('"')
        else:
            value = int(raw)
        out[m.group(2)] = {"value": value, "line": i, "raw": raw}
    return out


def value_status(value: object) -> str:
    if value == 0:
        return "silent"
    if isinstance(value, int):
        return "verified_store_audio" if value in VERIFIED_STORE_AUDIO else "uploaded_or_unverified_id"
    if isinstance(value, str) and value.startswith("rbxasset://"):
        return "verified_builtin" if value in VERIFIED_BUILTINS else "unverified_builtin"
    return "unknown"


def ffmpeg() -> str:
    exe = shutil.which("ffmpeg")
    if not exe:
        raise SystemExit("ffmpeg not found on PATH (needed to decode/encode audio)")
    return exe


def decode(path: Path) -> np.ndarray:
    """Any audio file -> mono float64 at 44.1 kHz."""
    cmd = [ffmpeg(), "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"]
    data = subprocess.run(cmd, check=True, capture_output=True).stdout
    return np.frombuffer(data, dtype="<f4").astype(np.float64)


def encode_ogg(samples: np.ndarray, path: Path, quality: int = 6) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.clip(samples, -1, 1).astype("<f4").tobytes()
    cmd = [ffmpeg(), "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
           "-c:a", "libvorbis", "-q:a", str(quality), "-map_metadata", "-1", "-fflags", "+bitexact",
           "-flags:a", "+bitexact", str(path)]
    subprocess.run(cmd, input=pcm, check=True, capture_output=True)


def db(x: float) -> float:
    return float(20 * np.log10(max(x, 1e-12)))


def peak_db(x: np.ndarray) -> float:
    return db(float(np.max(np.abs(x))) if len(x) else 0.0)


def rms_db(x: np.ndarray, gate_db: float = -50) -> float:
    """RMS of the parts louder than gate_db (50 ms windows), so silence does not drag it down."""
    if not len(x):
        return -120.0
    win = max(1, int(0.05 * SR))
    frames = [x[i:i + win] for i in range(0, len(x), win)]
    energies = np.array([np.mean(f ** 2) for f in frames if len(f)])
    gate = 10 ** (gate_db / 10)
    loud = energies[energies > gate]
    return db(float(np.sqrt(np.mean(loud if len(loud) else energies))))


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fingerprint(x: np.ndarray, bins: int = 64) -> np.ndarray:
    """Coarse loudness-envelope + spectrum fingerprint for near-duplicate detection."""
    if len(x) < bins:
        x = np.pad(x, (0, bins - len(x)))
    env = np.array([np.sqrt(np.mean(c ** 2)) for c in np.array_split(np.abs(x), bins)])
    spec = np.abs(np.fft.rfft(x))
    bands = np.array([np.mean(c) for c in np.array_split(spec, bins)])
    v = np.concatenate([env / (np.max(env) + 1e-12), np.log1p(bands / (np.max(bands) + 1e-12) * 100)])
    return v / (np.linalg.norm(v) + 1e-12)
