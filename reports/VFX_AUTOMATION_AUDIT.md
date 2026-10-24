# VFX Automation Audit: Style My Bestie

Date: 2026-10-24.

## Sources read
- `reports/Roblox SFX VFX GFX guide.md` **does not exist** in the repository (there was no `reports/` folder and no SFX/VFX/GFX document anywhere). The visual direction comes from `src/client/UI/Theme.luau` instead: an "after-party runway" look with deep plum panels, hot-pink interactive elements, an icy/electric cyan accent (`#62E2FF`), chrome/silver text (`#E6DDF5`) and gold for rewards. `README.md` and `LAUNCH_CHECKLIST.md` have no VFX guidance beyond "built from built-in objects".
- Every client and server effect file was read: `Stage.luau`, `MinigameFx.luau`, `Moments.luau`, `Round/Effects.luau`, `Auras.luau`, `MapDecor.luau`, plus the UI modules (HUD, Results, Voting, Stars, Reactions, Catalog, Lobby, Components, Kit).

## Effects already in the game
| Effect | Where | Notes |
| --- | --- | --- |
| Button press scale / hover | `Kit.button`, `Components` | Works. Kept. |
| Runway paparazzi flashes | `Stage.flashLoop` | Respects Settings > Flashing effects. Each flash is a Part + PointLight + 1 particle, destroyed after 0.08 s. Fine. |
| VIP golden scene tint | `Stage.vipGlow` | ColorCorrection tween, cleaned up. |
| Runway entrance cosmetics (Sparkles, Confetti, Spotlight, Fire...) | server `Round/Effects.luau` | Paid cosmetics, created on the server so everyone sees them. Not changed (monetisation). |
| Podium confetti burst | server `Effects.burst` | 250 particles, cleaned up by Debris. Kept. |
| Lobby moments: confetti/heart/snow/coin rain, Disco tint | `Moments.luau` | Paid moments. Rain used the default texture for every style; Disco was a colour tint only. |
| Minigame bursts, fireworks, screen flash, knockback shake, tile and disco-floor animation | `MinigameFx.luau` | Screen flash respects Flashing effects. Its own private `emitter`/`burst` helpers, with no budget. |
| Rank-up card with falling UI confetti | `HUD.celebrateRankUp` | Works. |
| Theme reveal card pop-in | `HUD.refreshRound` | Tween only, no particles. |
| Floating emoji reactions | `ReactionsUI.float` | Capped per walker. |
| Auras (cosmetic) | `shared/Auras.luau` | Particle/Trail/Light templates on the built-in sparkle texture. |

## Gaps against the requested list
| Requested | Status before |
| --- | --- |
| Player-matching effect, partner reveal | Missing (banner text only) |
| Theme reveal burst | Partial (pop-in only) |
| Teleport transition | Missing (hard camera cut when moved to booth / lobby) |
| Reward collection effect | Partial (a "+N" text under the coin pill) |
| Outfit completion sparkle (READY) | Missing |
| VIP / rare-outfit shimmer | Partial (VIP scene tint only) |
| Countdown warning pulse | Partial (timer text flashes red/white) |
| Runway spotlight sweep, volumetric beams, sparkle trail, stage accents | Missing (only paparazzi flashes) |
| Vote confirmation | Missing (button colour only) |
| Audience reaction burst | Partial (floating emoji, no world burst) |
| Winner reveal, top-three highlights | Partial (server confetti + "1st" tags) |
| Disco Mode stage lighting | Partial (tint only) |
| Selectable heart/star/sparkle trails | Not present. Adding them would create new shop items, a monetisation change that was out of scope, so they were not added. |
| Victory aura | Missing |
| Premium runway visual presets | Present as paid entrance cosmetics (server Effects) |

## Problems found
1. **No shared effect layer.** Stage, MinigameFx, Moments and the server each build emitters their own way. Only MinigameFx and Stage check the flashing setting, and nothing has a concurrency budget.
2. **No quality tiers.** Phones run the same particle counts as PCs.
3. **No reduced-motion support** beyond the flashing toggle.
4. **No custom particle shapes.** There are no heart, star or confetti textures: every effect uses the default sparkle.
5. **No problems that leak memory or hold an endless loop.** Every existing effect is destroyed after use (Debris, `task.delay`, or a disconnect), and the per-frame loops in MinigameFx and Moments are bounded.

## Built-in textures (checked in Studio)
`ContentProvider:PreloadAsync` with a fake path as a failing control: `sparkles_main`, `fire_main`, `smoke_main`, `fire_sparks_main`, `explosion01_core/shockwave/implosion_main`, `forcefield_glow_main` and `forcefield_vortex_main` all load. There is no built-in heart, star or confetti shape (`particles/star.png` and `particles/heart.png` fail).

## Prioritised plan (implemented, see VFX_AUTOMATION_FINAL.md)
1. Add a shared client module `Vfx.luau` with budgets, quality tiers, reduced motion, the flashing setting and self-cleanup, and route MinigameFx bursts through it.
2. Add `Config.Vfx`: texture IDs (0 = verified built-in fallback), palette, budgets.
3. Build a procedural texture pipeline (sparkle, heart, star, confetti, glow) with transparency, dimension and duplicate checks, a manifest and an upload manifest.
4. Hook the effects into the real handlers in this order: runway lighting, podium/winner, theme reveal, transitions, timer pulse, READY, votes, reactions, rewards, partner reveal, Disco.
5. Validation tooling, tests, and a Studio playtest.
