# SFX Automation Audit: Style My Bestie

Date: 2026-10-24. Scope: every sound the game references, how each one is configured, which gameplay events have no sound, and what the pipeline can reuse.

## Sources read

- `reports/Roblox SFX VFX GFX guide.md` is not in the repository. There was no `reports/` folder before this work, and no file matching `*sfx*`, `*vfx*` or `*gfx*` existed anywhere in the repo. Sound guidance only existed in `README.md` (lines 64, 83-85, 269) and `LAUNCH_CHECKLIST.md` §7 ("Music (optional)"). This audit is based on the code.
- Every `.luau` file under `src/` was scanned for `Sound`, `SoundId`, `rbxasset`, `playSound`, `Sounds.` and remote handlers.

## Existing audio architecture (before this work)

| Piece | Where | What it did |
| --- | --- | --- |
| `Config.Sounds` | `src/shared/Config.luau` | 11 keys: Click, PhaseChange, RunwayMusic, LobbyMusic, Heart, Podium, LobbyMoment, Reaction, Alert. Values were `rbxasset://sounds/...` paths or `0` (silent). |
| `Kit.playSound(key)` | `src/client/UI/Kit.luau:118` | One-shot UI sounds from `Config.Sounds`, volume 0.35, routed through the `SFX` SoundGroup. |
| `Audio` | `src/client/Audio.luau` | Creates the `Music` (0.5) and `SFX` (1.0) SoundGroups that the Settings switches mute; saves settings to the profile; built a 118 BPM runway beat from a hard-coded `BEAT` table; lobby music when `LobbyMusic` is set. |
| `MinigameFx` `SOUNDS` | `src/client/MinigameFx.luau:30` | Second, hard-coded table of 7 `rbxasset` paths for minigame effects and the Freeze Frame beat. |
| `Arena.Sounds` | `src/server/Lobby/Minigames/Arena.luau:37` | Third, hard-coded table of 13 `rbxasset` paths; the server sends them to clients through the `MinigameFx` remote. |

So sound IDs lived in three separate tables (Config, MinigameFx, Arena) plus the beat table in Audio. Swapping a sound meant finding the right one of four places.

## Asset status

Verified in Roblox Studio over the Studio MCP connection (a temporary `Sound` per path under `SoundService`, waiting for `IsLoaded`, reading `TimeLength`, then deleting the probe folder). A deliberately fake path was included as a control and did not load.

| Path | Loads | Length (s) | Used for |
| --- | --- | --- | --- |
| `rbxasset://sounds/clickfast.wav` | yes | 0.288 | Click, minigame Tick, beat hi-hat |
| `rbxasset://sounds/switch.wav` | yes | 0.235 | PhaseChange, Alert, minigame Switch |
| `rbxasset://sounds/snap.mp3` | yes | 0.418 | Heart, Reaction, beat clap, minigame Pop/Snap |
| `rbxasset://sounds/victory.wav` | yes | 1.306 | Podium, minigame Win |
| `rbxasset://sounds/Launching rocket.wav` | yes | 1.817 | LobbyMoment, minigame Launch |
| `rbxasset://sounds/bass.wav` | yes | 1.008 | minigame Go, beat kick |
| `rbxasset://sounds/glassbreak.wav` | yes | 1.578 | minigame Drop |
| `rbxasset://sounds/uuhhh.mp3` | yes | 0.332 | minigame Out |
| `rbxasset://sounds/hit.wav` | yes | 0.836 | minigame Hit |
| `rbxasset://sounds/swordslash.wav` | yes | 0.653 | minigame Whoosh |
| `rbxasset://sounds/flashbulb.wav` | yes | 0.360 | minigame / paparazzi Flash |
| `rbxasset://sounds/impact_explosion_03.mp3` | yes | 2.586 | minigame Boom |
| `rbxasset://sounds/impact_water.mp3` | yes | 2.377 | minigame Splash |

Most of these files are not in the installed client's flat `content/sounds` folder (it has 11 files). At first that made them look missing, but the Studio probe shows Roblox resolves them anyway. **All existing sounds work.** None is replaced by default.

- Placeholder IDs: `RunwayMusic = 0` (built-in beat) and `LobbyMusic = 0` (no lobby music).
- Uploaded `rbxassetid://` sound IDs: none.
- Invented or broken IDs: none found.
- Unrelated console error during the playtest: `ContentId: rbxassetid://203785492 failed due to: Asset type does not match requested type`. That ID is not in `src/` or `tools/`, so it comes from content in the place file. It is outside the audio system and was left alone.

## Problems found

1. **Three duplicate sound tables.** Config, MinigameFx and Arena each hard-coded paths, and Audio had a fourth beat table.
2. **One sound for many events.** `switch.wav` covered 4 events (phase change, alert, theme reveal, colour switch). `snap.mp3` covered 5 (heart, reaction, pop, snap, clap). `victory.wav` covered 3. Players cannot tell these events apart by ear.
3. **Silent gameplay events.** These had no sound at all:

| Event | Handler |
| --- | --- |
| Styling/voting timer reaches 10 s | `HUD.luau` heartbeat timer (only the colour flashed) |
| Stylist taps READY | `Catalog.luau` READY button (generic click only) |
| A look starts its runway walk / VIP entrance | `Stage.luau` `RunwayEffect` handler |
| Reward summary (coins/XP) | `HUD.showRewards` |
| Rank up | `HUD.celebrateRankUp` (confetti, no sound) |
| Quest claimed | `QuestsUI.luau` |
| Daily reward claimed | `LobbyUI.luau` |
| Cosmetic bought with coins | `ShopUI.luau` |
| Cosmetic equipped | `ShopUI.luau` |
| Outfit saved | `WardrobeUI.luau` |
| Theme reveal (dedicated sound) | `HUD.refreshRound` played the generic PhaseChange |
| 1st place (dedicated sound) | `ResultsUI.luau` played the same Podium sound for all three places |

4. **No music.** The runway used a click-built beat, and the lobby had no music.
5. **Unused key.** Arena's `Snap` sound is defined but no minigame plays it.
6. **No per-call volume.** `Kit.playSound` always used 0.35.

## Prioritised plan (what was then implemented)

1. Move every sound into `Config.Sounds` and add `Config.soundId(key)`. Point MinigameFx, Arena and Audio at it, keeping the same values so behaviour does not change.
2. Add one key per silent event (value 0 until a file is uploaded) and hook each key into its real handler.
3. Music: use Roblox Creator Store tracks from Roblox's licensed partner (APMOfficial), checked in Studio, so they need no upload.
4. Generate an original file locally for every key (procedural synthesis, no licence risk), then batch-process (trim, normalise, loop, OGG), check for duplicates and write the manifest.
5. Upload tooling: an upload-ready folder, an upload CSV, an optional official Open Cloud uploader, and `sync_ids.py`, which writes uploaded IDs back into `Config.Sounds`.
6. Validation script and tests.

Machine-readable inventory: `assets/audio/sfx_manifest.json` (every file, Config key, status, licence and rejected candidate).
