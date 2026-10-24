# VFX Automation: Final Report

Date: 2026-10-24. See `VFX_AUTOMATION_AUDIT.md` for the starting state.

## What was built

### Shared effect layer: `src/client/Vfx.luau`
One module that every client system now uses:
- **3D:** `burst` (Sparkle, Heart, Star, Confetti, Glow), `emit` (raw emitter props), `attach` (continuous sparkle or aura), `trail`, `highlight` (optional slow shimmer), and `lightBeam` (a fake volumetric light shaft: a FaceCamera Beam with the soft glow texture).
- **2D:** `uiBurst` (sparkles, hearts, stars, coins or confetti flying out of a UI element, or towards one), `uiConfetti`, `edgePulse` (a soft screen-edge glow), `transition` (a fade that covers teleports), `shimmer` (a chrome sheen sweep) and `pop`.
- **Budgets** (`Config.Vfx`): at most 10 live 3D bursts, 60 UI particles and 8 Highlights. Anything over budget is skipped, never queued.
- **Quality:** phones (touch only) and low manual graphics settings get 45% of the particles, and no trails or extra point lights. Disco draws 2 beams instead of 4.
- **Comfort:** Roblox's own *Reduced Motion* setting removes travel, sweeps, shuffles, pulses and UI confetti (effects fade in place instead). Settings > *Flashing effects* still controls every flash, and edge pulses are halved when it is off. None of the new effects strobe: the fastest repeat is the once-a-second timer glow.
- **Cleanup:** every effect removes itself (a tween `Completed`, `task.delay` after particle lifetime, or a returned stop function). Phase-bound effects (runway, podium) are cleared when the phase changes.

`MinigameFx.burst` now goes through `Vfx.emit`, so minigames share the budget and quality scaling, and their look is unchanged.

### Gameplay integration (real handlers)
| Moment | Handler | Effect |
| --- | --- | --- |
| Pairing | `HUD.partnerReveal` | The banner shuffles through names, then lands on your partner with a pop, a chrome shimmer and sparkles |
| Lobby → booth, Results → lobby | `HUD.phaseEffects` | Plum fade covering the teleport |
| Theme reveal | `HUD.refreshRound` | Sparkle burst and shimmer on the theme card |
| Styling: last 10 s | HUD timer tick | Soft red edge glow once a second, slightly stronger each second |
| Styling ends | `HUD.phaseEffects` | One soft cyan edge glow (time up) |
| READY tapped | `Catalog` | Sparkles off the button and a cyan burst around your mannequin |
| Runway walk starts | `Stage.runwayEntrance` (RunwayEffect remote) | Two light beams sweep from the runway end onto the walker (cyan + chrome), then a light pool, a sparkle trail and a ribbon trail follow them |
| VIP walk | same | Gold beams, more sparkles, a breathing chrome/gold Highlight (the existing VIP tint is kept) |
| Heart vote / star rating | `VotingUI`, `StarsUI` | Hearts or stars burst from the button (more stars, more sparkle) |
| Audience reaction | `ReactionsUI.float` | Small heart burst at the walker's head (throttled to one per 0.3 s per walker) |
| Results 3rd → 2nd → 1st | `Stage.podiumReveal`, `ResultsUI` | Bronze/silver/gold Highlights in step with the UI rows; the winner gets a gold light shaft, a star burst, a glow and a star aura; the rows burst; on-screen confetti if your look, or the look you styled, won |
| Coins gained | `LobbyUI.coinPop` | Coins fly from the middle of the screen into the coin counter |
| Rank up | `HUD.showRewards` | Star burst on top of the existing rank-up card |
| Disco Mode (bought moment) | `Moments.disco`, `Stage.setDisco` | Party-coloured beams turn under the disco ball, and runway spotlights switch to party colours while it lasts |
| Heart / confetti rain | `Moments.rain` | Uses the heart and confetti textures (fallback until upload) |

Not changed: the paid runway entrance cosmetics, the auras, lobby moment purchases, the server podium confetti and the paparazzi flashes. No new shop items were added (see Remaining work).

### Texture pipeline: `tools/vfx/vfx_pipeline.py`
- Draws five textures from signed-distance shapes (no external art): Sparkle, Heart, Star, Confetti and Glow. Masters are 1024 px (`assets/vfx/source/`) and processed textures are 256 px (`assets/vfx/processed/`). RGB is pure white with straight alpha, so `ParticleEmitter.Color` tints them cleanly.
- Checks: power-of-two size, at most 1024 px, a transparent border (edge alpha 0, so a shape cannot be clipped), coverage that is neither empty nor a full square, white RGB, and no duplicate hashes. The checks caught two real defects during development (sparkle arms touching the border, an inverted star) and both were fixed.
- Writes `assets/vfx/manifests/vfx_manifest.json` (textures, licence, checks, hashes, fallbacks, verified built-ins, and every effect with its handler and how it was verified) and `upload_manifest.csv`.
- `--check` also confirms that `Config.Vfx` lists exactly these textures, that every fallback is a Studio-verified built-in, that every non-zero ID is recorded as uploaded, and that every `require(...Vfx)` path resolves to `src/client/Vfx.luau`.
- `--set Heart=<id> ...` records upload IDs in the manifest and writes them into `Config.Vfx.Textures`.
- Until IDs are set, `Config.textureId()` uses the verified built-ins (`sparkles_main` for shapes, `forcefield_glow_main` for glow), so every effect already works.

## Validation

**Automated (all pass):**
- `python -m unittest discover -s tests -p "test_*.py"`: 19 tests OK (8 VFX: PNG round trip, every texture passes, opaque/oversize/tinted images are rejected, shapes are distinct, ID setter on temp copies, config and require paths, manifest against files; plus the 11 audio tests).
- `python tools/vfx/vfx_pipeline.py --check`: 5 textures OK, config and require paths OK.
- `python tools/audio/validate_sfx.py`: OK. `luau tests/Pairing.spec.luau`: passed.
- `stylua --check src`: clean. `selene src`: 3 errors and 8 warnings, the same as the base commit. The new and changed effect code adds no lint errors or warnings.

**Studio playtest (actually run through the MCP connection, solo, Rojo-synced):**
- Primitives: a burst of every kind, then 20 extra bursts. The budget refused 15 of them (10 live max). Highlight, attached sparkle, trail, beam, UI bursts, confetti, edge pulse and transition all appeared. **After 4 s everything was back to zero**: no leftover Terrain attachments, emitters on the character, or UI pieces.
- A real round driven by the admin remote (StartNow / SkipPhase):
  - Pairing showed the fade (transition opacity reached 0).
  - ThemeReveal showed 18 UI sparkles plus the shimmer.
  - Leaving Styling showed the time-up edge glow.
  - On the runway: 2 beams, a trail, a sparkle emitter and a light pool on the walker, all removed when the phase changed.
  - Results: winner Highlight, light shaft and star aura, and up to 40 UI particles (row bursts + confetti). All removed on return to the lobby, and the results-to-lobby fade played.
  - The console had no errors from game code. The only error was a pre-existing `rbxassetid://203785492` asset-type error from place content, which is unrelated.
- **Not verified in Studio:** partner reveal (needs 2 players; solo styling skips it by design), READY sparkle, vote and star bursts (need a real button press), reaction burst, coin fly-in, the 10-second countdown pulse, VIP visuals (needs the VIP pass), Disco preset (needs a bought moment), the low-quality path on a phone, and the reduced-motion path. These were code-reviewed and lint-checked only. **No visual screenshot review was done**, so look and feel still needs your eye.

## Remaining manual actions
1. ~~Upload the 5 textures~~ **Done (2026-10-25).** All five were uploaded as Image assets by the group that owns the place (454988084) and recorded in `Config.Vfx.Textures` and the manifest. In a playtest, every effect's emitter used the new ID, and every image loaded successfully.
2. **Two-player test in Studio** (Test > Clients and Servers, 2 players): check the partner reveal, READY sparkle, hearts/stars, reactions and the countdown pulse.
3. **Phone check:** Studio's device emulator, or a real phone, to look at the low-quality path.
4. **Comfort check:** turn on Reduced Motion in the Roblox settings and turn off Flashing effects in game settings, then play one round.
5. **Decide on selectable trails.** Heart/star/sparkle trails as shop items would be a new monetised product. `Vfx.trail` and `Vfx.attach` are ready if you want them added to `Config.Cosmetics`.

Nothing was published, and no ownership, permissions, monetisation or unrelated gameplay was changed.
