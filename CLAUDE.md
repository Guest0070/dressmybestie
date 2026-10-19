# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

"Style My Bestie": a round-based Roblox fashion game. Players pair up, secretly style each other's
mannequin from the Roblox catalog, walk a runway in the look they were given, and rate the looks.
Owner: Divyansh, new to Roblox Studio, ₹0 budget. He tests in Studio on Windows and sends
screenshots and Output logs. Explain Studio steps click by click.

## Commands

Toolchain is pinned in `rokit.toml` (rojo, wally, selene, stylua). Run `rokit install` after a fresh clone.

```
wally install                      # ProfileStore -> ServerPackages/ (must exist before rojo serve/build)
rojo serve                         # live-sync into Studio (Plugins > Rojo > Connect)
rojo build -o out.rbxlx default.project.json   # build check
stylua src                         # format (tabs, width 110, always parens)
selene src                         # lint (std = roblox; needs network for the API dump)
luau tests/Pairing.spec.luau       # the only unit test (pure Luau, no Roblox); standalone Luau CLI
```

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

## Architecture

**Rojo mapping** (`default.project.json`): `src/shared` → `ReplicatedStorage.Shared`, `src/server` →
`ServerScriptService.Server`, `src/client` → `StarterPlayerScripts.Client`, `ServerPackages` →
`ServerScriptService.ServerPackages`. Rojo does **not** manage StarterGui, Workspace or ServerStorage.
Anything Divyansh builds or imports in Studio lives only in the place file, so he must
File > Save to Roblox.

**Boot**: `server/init.server.luau` and `client/init.client.luau` require every system and call
`.start()` in an explicit order. Modules never start themselves. The client entry also wires modules
together through callback hooks (`LobbyUI.onOpenShop = ShopUI.open`, etc.) instead of modules
requiring each other.

**Networking**: every RemoteEvent/Function is declared by name in `shared/Remotes.luau`. The server
creates them and clients wait for them. Add a remote there, never ad hoc.

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

**UI**: two toolkits coexist.
- `UI/Kit.luau`: the older pink design-unit toolkit (a scaled 900x450 root). Most screens still use it.
- `UI/Theme.luau` + `UI/Components.luau`: the newer charcoal/cyan design system, used by LobbyUI,
  ShopUI and SettingsUI. These three are designable in Studio. `Components.designable(name, build,
  wire)` uses a ScreenGui of that name from StarterGui when one exists and finds every piece by Name;
  otherwise it builds the default. `build` only creates instances and `wire` attaches all behaviour,
  so both paths share `wire`. Keep the names that `wire` looks up stable: Divyansh's Studio designs
  depend on them.
- `Kit.playSound` routes through the SFX SoundGroup, which `Audio.luau` mutes from Settings.

## Docs to keep in sync

`README.md` covers player-facing features, Studio setup and test steps, the import and designable-UI
workflows, and where Roblox differs from the brief. `LAUNCH_CHECKLIST.md` lists the manual steps
Divyansh must do himself: product IDs, game settings, saving the place. Update both when a feature
changes what he has to do in Studio.
