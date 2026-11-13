# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Style My Bestie: a round-based Roblox fashion game (Luau, synced into Studio with Rojo). `README.md` has the full player-facing feature list and Studio setup; `LAUNCH_CHECKLIST.md` lists the manual dashboard steps (product IDs, badges, uploads).
Owner: Divyansh, new to Roblox Studio, ₹0 budget. He tests in Studio on Windows and sends
screenshots and Output logs. Explain Studio steps click by click.

## Commands

Toolchain is pinned in `rokit.toml` (rojo, wally, selene, stylua, luau-lsp, luau). On Windows, use PowerShell or the Bash tool.

```
rokit install              # once
wally install              # downloads ProfileStore into ServerPackages/ (needed before rojo serve)
rojo serve                 # then Studio > Plugins > Rojo > Connect
rojo build -o out.rbxlx default.project.json   # build check
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

## Type checking

Type checking: every file is `--!strict`. Use luau-lsp with a Rojo sourcemap:
`rojo sourcemap default.project.json -o sourcemap.json`, then
`luau-lsp analyze --platform roblox --sourcemap sourcemap.json --defs=<roblox globalTypes.d.luau> --ignore "**/ServerPackages/**" src`.
Keep it at zero errors. Nothing runs Roblox here, so gameplay is only verified in Studio, or with a
Lune harness that stubs services (as was done for `Tools/BlendImport`).

## Brief constraints (keep these)

- Server-authoritative. Clients only send intents; the server validates every remote payload.
- All tunables live in `src/shared/Config.luau`: timings, rewards, themes, cosmetics, product IDs
  (0 = shows "Soon"), sounds, admin IDs.
- Player data goes only through ProfileStore (`server/Data/PlayerData.luau`). Never call DataStore directly.
- `ProcessReceipt` must be idempotent: the purchase ID is saved with the grant, and the receipt is
  granted only after the save. Never sell random items.
- No free text anywhere, including catalog search. No visible last place. `Config.VotingMode`
  switches "Stars" (current) back to "Hearts" (the original brief: hearts only).
- R15 only; the wardrobe is the Roblox catalog. Looks may only use the asset types in `Config.AssetRules`.
- Mobile-first UI. Commit after each working step. When a Roblox API differs from the brief, tell
  Divyansh and note it in README "Places where Roblox differs from the brief". The code uses the
  `…Async` API variants, e.g. `ApplyDescriptionAsync` and `GetProductInfoAsync`.

## Architecture details

**Boot**: `server/init.server.luau` and `client/init.client.luau` require every system and call
`.start()` in an explicit order. Modules never start themselves. The client entry also wires modules
together through callback hooks (`LobbyUI.onOpenShop = ShopUI.open`, etc.) instead of modules
requiring each other.

**Client state**: `client/State.luau` caches what the server sent (`round`, `data`) and fires
`RoundChanged` / `DataChanged` signals that UI modules subscribe to. `State.canUseLobby()` and
`State.isParticipant()` decide which UI shows in which phase.

**Round loop**: `server/Round/RoundManager.luau` runs Lobby → Pairing → ThemeReveal → Styling →
Runway → (Voting, Hearts mode only) → Results. It broadcasts one `RoundState`
(`shared/Types.luau`). Pairing logic is pure (`Round/Pairing.luau`, unit-tested). Stylists edit the
target's mannequin. `Styling/LookValidator` + `AssetInfo` check every catalog ID on the server, and
`LookApplier` builds HumanoidDescriptions and restores outfits. Spectators are players with the
`Spectating` attribute.

**Player data**: to add a saved field, add it to the TEMPLATE in `PlayerData.luau` and to
`Types.PlayerData`; `profile:Reconcile()` backfills old saves. Expose it to clients through
`PublicData`. Mutate only through `PlayerData.update(player, fn)`. Studio sessions use `Steal`, so
stale locks don't block testing.

**Map contract**: `server/Round/Map.luau` finds named marker parts under `Workspace.Map`
(`Lobby.Spawn`, `Runway.Start/End/Camera/Audience/Lineup`, `Podium.First/Second/Third`,
`Booths.Booth_<n>.Stand/Mannequin`). It builds placeholders only for what's missing, so the game runs
on an empty Baseplate. Styling booths are clones of `ServerStorage.SMB_BoothTemplate` when it exists.
Placeholder decor is `Round/MapDecor.luau`. It skips its own kiosks and arch when
`Map.Lobby` has the `ImportedMap` attribute.

**Imported Blender building**: `assets/models/SMB_*.glb` were exported from Divyansh's .blend files
by `tools/blender/*.py` (bpy): meshes split per material, under the 20k-triangle limit, 1 m = 1 stud.
`server/Tools/BlendData.luau` (materials, lights, markers, group bounds) and `BlendPieces.luau`
(exact centre/size of every piece) are **generated**; regenerate them, don't hand-edit.
`Tools/BlendImport.apply()` runs from the Studio command bar in Edit mode. It matches imported
MeshParts by a loose name key and snaps each one to its Blender position and size. Studio shortens
names over 50 characters to "first23...last24", so matching handles that. It then anchors and styles
the pieces, adds lights and creates all the Map markers and kiosks. `autoSetup()` repeats this at
server start if the setup was never saved. The command bar caches `require`: to run edited code
without restarting Studio, clone the module next to the original and require the clone.

**Lobby**: `server/Lobby/*` holds the skin-tone/body-type booths (`Appearance`, walk-in zones with
a `BoothPanel` attribute, detected on the client), Dressing Room, Hall of Fame, activities,
environment and the `Minigames/` folder. Each minigame is its own module, coordinated by
`Minigames/init.luau`, and runs in the plaza "Play Zone" or the imported arcade hall.

**UI**: two toolkits, one look. `UI/Theme.luau` holds every colour, font and radius (deep plum
panels, hot-pink actions, gold rewards), and both toolkits read it, so restyling means editing tokens.
- `UI/Kit.luau`: the older toolkit. It draws into a "Root" frame in design units (about 900x450),
  scaled to the screen by a UIScale. Most in-round screens use it (HUD, Catalog, Voting, Results...).
- `UI/Components.luau`: the newer scale-plus-constraints components. LobbyUI, ShopUI, SettingsUI,
  MinigameUI, ReactionsUI and WardrobeUI use them.
- LobbyUI, ShopUI and SettingsUI are designable in Studio. `Components.designable(name, build, wire)`
  uses a ScreenGui of that name from StarterGui when one exists and finds every piece by Name;
  otherwise it builds the default. `build` only creates instances and `wire` attaches all behaviour,
  so both paths share `wire`. Keep the names that `wire` looks up stable: Divyansh's Studio designs
  depend on them.
- `Kit.playSound` routes through the SFX SoundGroup. `Audio.luau` mutes it from Settings, and saves the
  music, SFX and flashing-effects settings to the profile.

## Rules carried over from the README

- Monetisation: nothing random is sold, and every item has a fixed outcome. Pass ownership comes only from `UserOwnsGamePassAsync`, and coin prices only from `Config`. There are no fake timers or pressure prompts. Coins buy cosmetics only, never a voting advantage.
- Safety: no free-text input anywhere (themes come from Config). Voters stay anonymous, and there is no last place. A look can only change clothing, accessories, face and emotes, never body parts, skin or head.
- Roblox APIs marked deprecated are replaced by their `…Async` versions.

## Working with Studio (MCP)

When the Roblox Studio MCP is connected and Rojo is serving, edits sync live into the open place, so you can playtest with `start_stop_play` and probe with `execute_luau`. Inside `execute_luau`, `require` of a game ModuleScript returns a **fresh copy**, not the running instance, so its state (for example `State.round`, `RoundManager` flags) is misleading. Observe real artifacts instead (PlayerGui, Workspace, remotes such as `GetRoundState`), or drive the game through remotes (`AdminCommand`).

## Docs to keep in sync

`AUDIT.md` (state of the code, 13 Nov 2026), `REDESIGN.md` (design decisions and why), `PLAN.md`
(what is done, next, and deliberately deferred) and `CHANGELOG.md` (every change with its Studio test).
Add a CHANGELOG entry and bump `Config.Build` with each batch of changes.

`README.md` covers player-facing features, Studio setup and test steps, the import and designable-UI
workflows, and where Roblox differs from the brief. `LAUNCH_CHECKLIST.md` lists the manual steps
Divyansh must do himself: product IDs, game settings, saving the place. Update both when a feature
changes what he has to do in Studio. `reports/` holds research write-ups (e.g. the SFX/VFX/GFX guide),
with their sources in `research_notes/`; check them before re-researching Roblox audio, effects,
lighting or store-page rules.
