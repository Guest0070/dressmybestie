# SFX Automation: Final Report

Date: 2026-10-24. See `SFX_AUTOMATION_AUDIT.md` for the starting state.

## What changed

### One sound configuration
- `src/shared/Config.luau`: `Config.Sounds` now holds every sound in the game (39 keys, grouped UI / Gameplay / Runway / Results / Rewards / Music). The new `Config.soundId(key)` returns the playable SoundId, or `nil` for a silent key.
- `MinigameFx.luau`, `Arena.luau` and `Audio.luau` no longer hard-code paths; they read `Config.soundId`. Every existing key keeps its previous value, so all old sounds play exactly as before. In the playtest, Arena's table was identical to the old one.
- `Kit.playSound(key, volume?)` takes an optional volume (default 0.35, as before).

### New event hooks (real handlers, not demos)
| Key | Handler | Plays when |
| --- | --- | --- |
| `TimeWarning` | `HUD.luau` timer | styling or voting reaches 10 s (once per phase) |
| `Ready` | `Catalog.luau` READY button | a stylist marks themselves ready |
| `ThemeReveal` | `HUD.refreshRound` | the theme card appears (was PhaseChange; same sound for now) |
| `RunwayEntrance` / `VipEntrance` | `Stage.luau` `RunwayEffect` | each look starts walking |
| `Coins` / `RankUp` | `HUD.showRewards` | the round's reward summary arrives |
| `Winner` | `ResultsUI.luau` | the 1st-place row appears (was Podium; same sound for now) |
| `QuestClaim`, `DailyReward`, `Purchase`, `Equip`, `OutfitSaved` | QuestsUI, LobbyUI, ShopUI, WardrobeUI | the button for that action is pressed (each button only shows when the action is possible) |

Keys that are new and have no uploaded sound are `0` and play nothing. In the playtest, `Kit.playSound("Ready")` created no Sound.

### Music (live now, no upload needed)
| Key | Asset | Source | Check |
| --- | --- | --- | --- |
| `LobbyMusic` | 1846743916 "It's Party Time (B)" | APMOfficial, Creator Store | loaded in Studio, 141.5 s, played in the lobby during the playtest |
| `RunwayMusic` | 1839940316 "Jump Up" | APMOfficial, Creator Store | loaded in Studio, 60.4 s |

Both tracks loop through the existing `Audio.luau` code (`Looped = true`) and go through the `Music` group, so Settings > Music still mutes them. Setting `RunwayMusic = 0` brings back the built-in beat. Licence: APM Music is Roblox's partner library, free for use in Roblox experiences, including monetised ones. It covers use on Roblox only, so these tracks must not go into off-platform trailers.

### Pipeline (`tools/audio/`)
| Step | Command | Output |
| --- | --- | --- |
| Generate | `python tools/audio/generate_sfx.py` | 31 original WAVs + licence sidecars in `assets/audio/source/generated/` (deterministic, byte-identical on re-run) |
| Process | `python tools/audio/process_sfx.py` | `assets/audio/processed/<Category>/<id>.ogg`, `sfx_manifest.json`, `upload_manifest.csv` |
| Upload (optional) | `python tools/audio/upload_opencloud.py --user-id <id> --yes` | official Open Cloud Assets API, needs your API key |
| Apply IDs | `python tools/audio/sync_ids.py --set <file>=<assetId> ...` | writes IDs into `Config.Sounds` |
| Validate | `python tools/audio/validate_sfx.py --json reports/sfx_validation.json` | errors/warnings, exit code |

Processing decodes any format (ffmpeg), trims leading and trailing silence (-60 dB, 5 ms fade), folds music tails onto the loop start so loops are seamless, normalises to a per-sound RMS target under a -1 dBFS peak ceiling (-1.5 for loops), encodes OGG Vorbis q6, then decodes again to measure the result. Originals are never modified. Licence gate: a source without a sidecar, without verified commercial-use rights, or needing attribution that is not recorded is rejected. External CC0 files can be dropped into `assets/audio/source/external/<id>.<ext>` with a sidecar, and they go through the same steps.

## Validation results

- `python tools/audio/validate_sfx.py`: **OK, 0 errors, 0 warnings.** 31 files, 39 Config keys. Every key the code plays exists, and every value is silent, a Studio-verified built-in or a Studio-verified store ID. No sound paths are hard-coded outside `Config.Sounds`.
- `python -m unittest discover -s tests -p "test_*.py"`: 11 tests OK (Config parsing, ID sync including CRLF, trim, no-clip normalisation, loop folding, licence gate, manifest against files and hashes).
- `luau tests/Pairing.spec.luau`: passed (existing test).
- `stylua --check src`: clean. `selene src`: 3 errors and 8 warnings, all already on the base commit (same counts with my changes stashed). None is in the changed lines.
- **Studio playtest (actually run through the MCP connection):** server and client started; `LobbyMusic` was playing (loaded, `Music` group); `RunwayMusic` was loaded and waiting for the runway phase; `Kit.playSound("Click", 0.2)` created one Sound in the `SFX` group at volume 0.2, and it was removed after playing; a silent key was a no-op; `Arena.sound("")` was a no-op. A full round (styling, runway, results) was **not** played through, so the new event sounds were not heard in context. They are silent until upload anyway.

### Volume and loop settings
- Music: Sound volume 0.5 inside the `Music` group at 0.5. Loops: `Looped = true` on both tracks. The generated fallback loops measured seamless (seam step under the music's own typical sample step).
- SFX: `Kit.playSound` 0.35 default; new reward/runway/warning sounds use 0.5; minigame sounds keep their per-call volumes. Generated files are normalised to -16 to -22 dBFS RMS by role, and every peak is at or below -1.0 dBFS.

### Duplicates and unused audio
- No exact or near duplicates among the generated files (hash and fingerprint check).
- Shared values that still exist on purpose (until uploads land): `switch.wav` ×4, `snap.mp3` ×5, `victory.wav` ×3, `clickfast.wav` ×3, `bass.wav` ×2, `Launching rocket.wav` ×2. The pipeline prepared a distinct file for each of these events (priority 2).
- `MinigameSnap`: defined in `Arena.Sounds`, never played by any minigame.
- `BeatKick`/`BeatHiHat`/`BeatClap`: the runway beat no longer plays now that `RunwayMusic` is set. Kick and hi-hat are still used by the Freeze Frame dance beat; clap is only used if `RunwayMusic` goes back to 0.

### Licence status
| Group | Count | Status |
| --- | --- | --- |
| Generated files | 31 | Original work by `generate_sfx.py` (oscillators and seeded noise, no samples). Verified, commercial use allowed, no attribution. |
| Creator Store music | 2 | APMOfficial, verified to load; licensed for use in Roblox experiences. |
| Built-in `rbxasset` sounds | 13 | Ship with Roblox; verified to load. |
| Rejected | n/a | User-uploaded Creator Store SFX (unclear rights: ripped game audio, "personal use", freesound credit needed). Listed in the manifest. |

## Upload priorities (`assets/audio/upload_manifest.csv`)
- **P1, 9 files: fill the 11 silent events.** `ui_time_warning`, `ui_ready`, `rw_entrance`, `rw_vip_entrance`, `rs_rank_up`, `rw_coins`, `rw_claim` (QuestClaim + DailyReward), `rw_purchase`, `rw_equip` (Equip + OutfitSaved). This fits the 10-per-month limit for accounts without ID verification.
- **P2, 20 files:** optional, more distinct replacements for working built-ins. These are only applied with `sync_ids.py --include-replacements`.
- **P3, 2 files:** generated music loops, a fallback in case the APM tracks are ever removed.

## The only things left for you to do

1. **Upload the 9 P1 files** in `assets/audio/processed/` (listed first in `upload_manifest.csv`). Use the account or group that owns the experience. Two options:
   - Studio: **Window > Asset Manager > Bulk Import**, pick the 9 `.ogg` files, then copy each new ID (right-click > Copy Asset ID).
   - Or create an Open Cloud API key (Creator Hub > Open Cloud > API Keys, permission **Assets: read + write**), set `ROBLOX_API_KEY`, and run `python tools/audio/upload_opencloud.py --user-id 11736753688 --yes`. The script records the IDs itself.
2. **Write the IDs into Config:** `python tools/audio/sync_ids.py --set ui_ready=<id> rw_coins=<id> ...` (no `--set` needed after the Open Cloud script), then `python tools/audio/validate_sfx.py`.
3. **Listen once in Studio** to a full round: check that you like the two APM tracks (swap the IDs in `Config.Sounds` if not) and that the new sounds sit well in the mix.
4. Optional: upload P2 files later, when you have spare quota, and apply them with `--include-replacements`.

Nothing was published, and no ownership, permissions or monetisation settings were touched.
