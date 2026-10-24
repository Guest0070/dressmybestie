# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Style My Bestie: a round-based Roblox fashion game (Luau, synced into Studio with Rojo). `README.md` has the full player-facing feature list and Studio setup; `LAUNCH_CHECKLIST.md` lists the manual dashboard steps (product IDs, badges, uploads).

## Commands

Toolchain is pinned in `rokit.toml` (rojo, wally, selene, stylua, luau-lsp, luau). On Windows, use PowerShell or the Bash tool.

```
rokit install              # once
wally install              # downloads ProfileStore into ServerPackages/ (needed before rojo serve)
rojo serve                 # then Studio > Plugins > Rojo > Connect
stylua src                 # format (stylua --check src in CI-style checks)
selene src                 # lint; the base has 3 errors + 8 warnings already: compare counts, don't chase them
luau tests/Pairing.spec.luau                          # the only plain-Luau test
python -m unittest discover -s tests -p "test_*.py"   # audio + VFX pipeline tests (need numpy; audio needs ffmpeg)
python -m unittest tests.test_vfx_pipeline.Checks.test_opaque_background_is_rejected   # one test
```

`Config.luau` uses Roblox types (`Color3`...), so it cannot be required from the standalone `luau` CLI. Only pure modules such as `Round/Pairing.luau` are unit-testable there.

Asset pipelines (Python, offline, deterministic):
- Audio: `tools/audio/generate_sfx.py` → `process_sfx.py` (writes `assets/audio/processed/<Category>/*.ogg`, `sfx_manifest.json`, `upload_manifest.csv`) → `validate_sfx.py`. After uploading, `sync_ids.py --set <file_id>=<assetId>` writes IDs into `Config.Sounds` (silent keys only unless `--include-replacements`). `upload_opencloud.py` is the optional Open Cloud uploader (needs the user's `ROBLOX_API_KEY`).
- VFX textures: `tools/vfx/vfx_pipeline.py` (build + validate + manifest), `--check` (validate only), `--set Heart=<id>` (after upload).
- Blender building: `tools/blender/*.py` regenerate `src/server/Tools/BlendData.luau`/`BlendPieces.luau` from `assets/models` (commands in README "Blender building").

## Architecture

Rojo maps `src/shared` → `ReplicatedStorage.Shared`, `src/server` → `ServerScriptService.Server`, `src/client` → `StarterPlayerScripts.Client`, and `ServerPackages` (ProfileStore, server-only) → `ServerScriptService.ServerPackages`. StarterGui is not managed by Rojo: LobbyUI/ShopUI/SettingsUI can use a Studio-designed ScreenGui found by child names, falling back to code-built UI.

**Server decides everything.** Clients only fire intent remotes. The server validates every payload, every catalog ID (`Styling/AssetInfo`, `LookValidator`, `Config.AssetRules`), every purchase and every vote.

- `src/shared/Remotes.luau`: every remote is declared by name here (flat folder `ReplicatedStorage.Remotes`). The server creates them; clients wait for them. A new remote means adding its name to `EVENT_NAMES`/`FUNCTION_NAMES`.
- `src/shared/Config.luau`: single source of truth for tunables and content (timings, themes, chaos modifiers, cosmetics, prices, product/pass IDs where `0` = not set up yet, quests, badges). Content changes should only touch this file.
  - `Config.Sounds` holds every sound ID, read through `Config.soundId(key)` (nil = silent). Client `Kit.playSound`, `MinigameFx`, `Audio` and server `Minigames/Arena` (keys `"Minigame" .. name`) all go through it. Don't hard-code sound paths elsewhere: `validate_sfx.py` fails on them.
  - `Config.Vfx` holds the particle texture IDs, read through `Config.textureId(key)`, which falls back to Studio-verified `rbxasset://textures/particles/*`; it also holds the palette and per-client budgets.
- `src/server/init.server.luau` starts every server system in order. `Round/RoundManager.luau` runs the loop Lobby → Pairing → ThemeReveal → Styling → Runway → Voting → Results. It broadcasts a `RoundState` (type in `shared/Types.luau`) on each phase change and teleports players at phase starts. Admin shortcuts (`StartNow`, `SkipPhase`) arrive through the `AdminCommand` remote (`server/Admin.luau`).
- Player data: `Data/PlayerData.luau` wraps ProfileStore (session-locked). New fields need a template default (Reconcile fills existing profiles). `ProcessReceipt` (`Monetization/Receipts.luau`) records the purchase ID in the same save as the grant.
- Client: `src/client/init.client.luau` starts the modules. `State.luau` mirrors `RoundState`/`PublicData` and exposes `RoundChanged(round, changedFrom)`/`DataChanged` signals that every UI reacts to. `Stage.luau` owns cameras, the movement lock, runway/podium lighting and paparazzi flashes. `Audio.luau` owns the Music/SFX SoundGroups and saved settings (`flashesOn` = Settings > Flashing effects). `Vfx.luau` provides the shared effect primitives with budgets, low-quality scaling, Roblox Reduced Motion and the flashing setting; new effects should use it rather than raw emitters. UI toolkits: `UI/Kit.luau` (older) and `UI/Components.luau`; both take tokens from `UI/Theme.luau` (plum/pink, cyan accent, chrome, gold).
- Lobby minigames: `server/Lobby/Minigames/*`. `Arena.luau` holds shared builders, rewards and `Arena.fx`/`Arena.sound`, which send effects to clients over the `MinigameFx` remote; `client/MinigameFx.luau` renders them.

## Rules carried over from the README

- Monetisation: nothing random is sold, and every item has a fixed outcome. Pass ownership comes only from `UserOwnsGamePassAsync`, and coin prices only from `Config`. There are no fake timers or pressure prompts. Coins buy cosmetics only, never a voting advantage.
- Safety: no free-text input anywhere (themes come from Config). Voters stay anonymous, and there is no last place. A look can only change clothing, accessories, face and emotes, never body parts, skin or head.
- Roblox APIs marked deprecated are replaced by their `…Async` versions.

## Working with Studio (MCP)

When the Roblox Studio MCP is connected and Rojo is serving, edits sync live into the open place, so you can playtest with `start_stop_play` and probe with `execute_luau`. Inside `execute_luau`, `require` of a game ModuleScript returns a **fresh copy**, not the running instance, so its state (for example `State.round`, `RoundManager` flags) is misleading. Observe real artifacts instead (PlayerGui, Workspace, remotes such as `GetRoundState`), or drive the game through remotes (`AdminCommand`).
