# Roblox VFX for "Style My Bestie" (state as of Oct 2026)

Research note: WebFetch could not resolve create.roblox.com or devforum.roblox.com in this environment. Official pages were read through Firecrawl scrapes; some of those were served from a cache dated 2026-10-19 or 2026-10-20, so they are current. Some figures come from search-result summaries rather than full page reads and are marked as such.

## Current Roblox VFX building blocks and their key properties

### Takeaway
Particles (with flipbooks), Beams, Trails, Highlights and local lights still form the core toolkit, and the documented properties support everything the game needs from code at runtime. One important correction: the Highlight limit is now **255 rendered at once**, not the old figure of 31. `Lighting.Technology` is deprecated in favour of `LightingStyle` plus `PrioritizeLightingQuality`. I found no official new particle or beam feature for 2025-2026.

### Cited Findings
**ParticleEmitter** ([API ref](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter))
- `Brightness` scales the emitted light when `LightInfluence` is 0. — [ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter)
- `LightEmission` 0 = normal blending, 1 = additive blending. A change applies instantly to current and future particles. — [ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter)
- `LightInfluence` ranges 0–1 (values outside are undefined). At 0, particles keep full brightness; at 1, they are fully lit by the environment (black in darkness). — [ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter)
- `ZOffset` is a fractional value in studs that moves particles toward the camera (positive) or away (negative) without changing their on-screen size. It is not an integer like ZIndex. — [ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter)
- `Rate` = particles per second while Enabled; a rate of 5 emits one every 0.2 s. A `Lifetime` of 0 emits nothing. Lifetime is stored per particle. — [ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter)
- `Emit(particleCount)` instantly emits that many particles; the default count is **16**. This is the burst tool for confetti, poofs and star bursts. — [ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter)
- `TimeScale` 0–1 (1 = normal, 0.5 = half speed, 0 = frozen). Useful for a "Freeze Frame" minigame effect. — [ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter)
- `Squash` is curve-controlled non-uniform scaling: >0 = thinner and taller, <0 = wider and shorter. — [ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter)
- `Orientation` options: FacingCamera (default), FacingCameraWorldUp, VelocityParallel, VelocityPerpendicular. VelocityParallel suits streak sparks and falling confetti strips. — [ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter)
- `Shape` = box, sphere, cylinder or disc; `ShapeStyle` = volume or surface emission. `LockedToPart` = particles move rigidly with the parent, which is good for auras on a walking avatar. `WindAffectsDrag` follows `Workspace.GlobalWind` only if Drag > 0. — [ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter)
- Flipbooks: `FlipbookLayout` = None / Grid2x2 (4 frames) / Grid4x4 (16) / Grid8x8 (64) / Custom (using `FlipbookSizeX`/`FlipbookSizeY`). `FlipbookMode` = Loop / OneShot / PingPong / Random. In OneShot, the framerate is Lifetime ÷ frames and `FlipbookFramerate` is ignored. Random crossfades between frames ("stars slowly twinkling"). `FlipbookFramerate` maximum is **30 fps** and accepts a min/max range. `FlipbookStartRandom` starts each particle on a random frame. The texture size must be an exact multiple of the layout. — [ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter)
- The Custom layout (FlipbookSizeX/Y) is newer than the 2022 release, which offered only Grid2x2/4x4/8x8. — [ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter) compared with [Flipbook release, Oct 2022](https://devforum.roblox.com/t/particles’-flipbook-release/2029388)
- Flipbooks left beta on **21 Oct 2022**. Textures can be any square power of two from **8x8 to 1024x1024**. The enum names changed from TwoByTwo/FourByFour/EightByEight to Grid2x2/Grid4x4/Grid8x8, so older tutorials using the old names are **outdated**. Leaving some spacing around frames is still recommended to avoid artifacts. — [DevForum: Particles' Flipbook Release](https://devforum.roblox.com/t/particles’-flipbook-release/2029388)
- Guide: a 1024×1024 texture in an 8×8 layout gives a 64-frame animation. Include spacing between frames. By default, emitters use a white sparkle texture. — [Particle emitters guide](https://create.roblox.com/docs/effects/particle-emitters)

**Beam** ([API ref](https://create.roblox.com/docs/reference/engine/classes/Beam))
- A Beam draws a texture between Attachment0 and Attachment1 as a Bézier curve (CurveSize0/CurveSize1). `Segments` defaults to 10. `FaceCamera` keeps segments facing the camera. `TextureMode` = Wrap / Static / Stretch. `TextureSpeed` (default 1) = texture cycles per second, which gives scrolling light shafts. `Width0`/`Width1` are in studs (a cone-shaped spotlight shaft is a narrow Width0 and a wide Width1). `Transparency` is a NumberSequence, so a shaft can fade out toward the floor. `LightEmission` 0–1 additive, `LightInfluence` 0–1, `Brightness` default 1 with range 0–10000 (applies when LightInfluence < 1), `ZOffset` in studs. — [Beam](https://create.roblox.com/docs/reference/engine/classes/Beam)

**Trail** ([API ref](https://create.roblox.com/docs/reference/engine/classes/Trail))
- `Lifetime` default 2 s (range 0.01–20). `MaxLength` default 0 (no maximum). `WidthScale` is a NumberSequence. `Brightness` default 1 (0–10000). `Clear()` removes all segments immediately, which is useful when teleporting a model to the runway start so it doesn't leave a long streak. — [Trail](https://create.roblox.com/docs/reference/engine/classes/Trail)

**Highlight** ([API ref](https://create.roblox.com/docs/reference/engine/classes/Highlight))
- "As a performance limit, Studio only displays **255** simultaneous Highlight instances on the client at a time." Extra instances are silently ignored. A Highlight with `Enabled = false` **still takes a slot**, so delete Highlights rather than disabling them. `FillTransparency` default 0 (opaque) to 1. `DepthMode` = AlwaysOnTop or Occluded. — [Highlight](https://create.roblox.com/docs/reference/engine/classes/Highlight)
- The commonly quoted limit of 31 is **outdated**; the current doc says 255. — [Highlight](https://create.roblox.com/docs/reference/engine/classes/Highlight)

**Lighting / lights**
- `Lighting.Technology` is marked **Deprecated**. `LightingStyle` expresses artistic intent: `Soft` (stylized) or `Realistic` (naturalistic). The actual shadow path also depends on `PrioritizeLightingQuality` (e.g. Soft with it enabled uses shadow maps, not voxel lighting). `PrioritizeLightingQuality = true` keeps shadows and high-quality shaders at close range as quality drops; `false` keeps view distance instead. — [Lighting](https://create.roblox.com/docs/reference/engine/classes/Lighting)
- The maximum `Range` of PointLight/SpotLight/SurfaceLight is **120 studs** (noted under `ExtendLightRangeTo120`). — [Lighting](https://create.roblox.com/docs/reference/engine/classes/Lighting)
- Post-processing children of Lighting: Atmosphere, Sky, BloomEffect, ColorCorrectionEffect, ColorGradingEffect, DepthOfFieldEffect, SunRaysEffect, BlurEffect. — local Roblox skill reference (roblox-skills plugin, roblox-world-building), not verified against a web source this session.

**New features 2024–2026**
- A search found no official 2025–2026 announcement of new particle or beam features. Results were feature requests (e.g. "rate over distance", true light emission from particles) and community plugins (Sine VFX, VFX Forge). — [DevForum VFX feature request](https://devforum.roblox.com/t/vfx-system-update-features/1293316), [Sine VFX plugin](https://devforum.roblox.com/t/plugin-sine-vfx-a-vfx-plugin-for-roblox-studio/4803771), [VFX Forge](https://zilibobi.itch.io/vfx-forge)
- A community module lets ParticleEmitters show inside UI (described by its author as "unoptimized"). — [DevForum: UI Particle](https://devforum.roblox.com/t/ui-particle-an-unoptimized-module-to-integrate-particleemitters-into-your-ui-with-minimal-coding/4004649)

### Inferences
- A runway spotlight works best as a combination: a SpotLight (real light on the walker) plus a Beam cone (Width0 small, Width1 large, Transparency fading 0.6→1, LightEmission 1, slow TextureSpeed) to show the visible shaft. Real volumetric light doesn't exist in Roblox, so a Beam is the standard way to fake it.
- Because the cap is now 255, Highlights can mark the current runway walker, the podium winners and the voted look. There's no reason to ration them to a handful; just delete them after use.
- For a "Freeze Frame" minigame, setting `TimeScale = 0` on active emitters is a cheap way to freeze them dramatically.
- With the mixed Kit/Theme UI, screen flashes and UIGradient sweeps are best done with TweenService on a full-screen Frame's BackgroundTransparency and on UIGradient.Offset/Rotation. These are cheap and need no textures. (Established practice; no specific source fetched.)

### Gaps
- I could not fetch the UIGradient, SurfaceGui/BillboardGui or Neon material pages because of rate limits. No new numbers were found for these.
- The default values of Highlight OutlineTransparency/DepthMode and of Trail FaceCamera/LightEmission were not stated in the scraped text.
- I could not confirm a maximum Beam `Segments` value or a hard cap on particle `Rate` from the scraped pages.

## Performance on mobile: budgets, profiling, quality adaptation, client-side spawning

### Takeaway
Particles, decals and textures don't batch and add draw calls. Transparency overdraw and shadow-casting lights are the main GPU costs. Texture memory scales with pixel count. Roblox publishes no per-device particle or light budget, so profile with the MicroProfiler and spawn every cosmetic effect on the client from a small RemoteEvent trigger.

### Cited Findings
- "Objects like decals, textures, and particles don't batch well and introduce additional draw calls." Also: "property changes to ParticleEmitters can have a dramatic impact on performance." — [Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- High transparency overdraw: overlapping semi-transparent objects force pixels to be rendered several times. — [Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- Shadows: the engine automatically degrades shadow quality as the graphics quality level drops, **disabling shadows entirely below quality level 4**. Recommendations: set `Light.Shadows = false` where shadows aren't needed, use `CastShadow = false` on small or distant parts, disable shadows on moving objects, limit light range and angle, use fewer lights, and disable lights outside a range or room. — [Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- Texture memory depends on pixels, not file size: a 1024×1024 texture uses **4×** the memory of a 512×512 one. Images usually need **at most 512×512** unless they fill a large part of the screen; most minor images should be **under 256×256**. — [Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- Flipbooks cost memory. When memory runs low, **clients automatically deactivate flipbooks**, which is "likely for older mobile phones". Use fewer unique animated effects and smaller textures, and reuse textures (reuse is cheaper than unique textures). — [Particle emitters guide](https://create.roblox.com/docs/effects/particle-emitters)
- MicroProfiler render scopes: `Prepare and Perform` (overall rendering), `Perform/Scene/computeLightingPerform` (light grid and shadow updates), `LightGridCPU` (voxel light grid), `ShadowMapSystem` (shadow mapping), `Perform/Scene/UpdateView` (render prep **and particle updates**), `Perform/Scene/RenderView` (rendering and post-processing). — [Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- Quality level: read it on the client with `UserSettings():GetService("UserGameSettings").SavedQualityLevel` (an `Enum.SavedQualitySetting`). It returns **Automatic** (value 0) for players on automatic graphics, not their actual automatic level, which makes it unreliable on many mobile devices. Watch changes with `GetPropertyChangedSignal("SavedQualityLevel")`. `GraphicsQualityLevel` needs Roblox script security, so game scripts cannot read it. — [DevForum: detect graphics level](https://devforum.roblox.com/t/2534448), [DevForum: reading graphic quality](https://devforum.roblox.com/t/reading-graphic-quality/1051261), [UserGameSettings docs](https://create.roblox.com/docs/en-us/reference/engine/classes/UserGameSettings.md) (claims taken from search summaries; forum posts are community advice)
- Client-side spawning pattern (community consensus): the server validates and then sends every client a small trigger (effect name + position or character), and each client builds the effect locally. Replicating the effect itself "is slow and laggy". Keep payloads small. FireAllClients does not reach players who join later, so replay ongoing effects (e.g. an active aura) for them separately. — [DevForum: client-sided VFX](https://devforum.roblox.com/t/client-sided-vfx/2792835), [DevForum: correct way of scripting VFX](https://devforum.roblox.com/t/correct-way-of-scripting-vfx/2439994), [DevForum: replicate to new players](https://devforum.roblox.com/t/2323228)
- Bug report: `UnreliableRemoteEvent:FireAllClients()` still attempts invocations for clients that aren't connected, contrary to the docs. — [DevForum bug report](https://devforum.roblox.com/t/unreliableremoteeventfireallclients-still-attempts-invocations-on-non-connected-clients-contrary-to-docs/3852670)

### Inferences
- Practical budget (my own working numbers, not from Roblox): keep constant emitters to a few per avatar at a Rate of about 5–20. Use `Emit(n)` bursts of about 20–60 for confetti and poofs instead of high constant rates. Keep particle textures at 256² or below, and only 1–2 shadow-casting lights (the runway key light). Every other light should have `Shadows = false`. Test the busiest moment (Results podium with confetti, all auras, crowd) on the cheapest phone available.
- Because SavedQualityLevel reports Automatic for most players, adapt effects with a **game setting** (the game already has Settings with a flashing toggle) and possibly a measured FPS fallback (e.g. halve emit counts if the average frame time stays above ~33 ms). Don't rely on the engine quality value alone.
- Spawning everything on the client also means a player's "flashing effects off" setting can be honoured per viewer, which server-replicated effects cannot do.
- Additive particles (LightEmission 1) that stack in front of the runway camera add both overdraw and wash-out. Keep big, soft particles away from the cinematic camera path, or use small particle sizes.

### Gaps
- Roblox publishes no official mobile particle-count, light-count or draw-call budget. None was found.
- `GuiService.ReducedMotionEnabled` exists (see Accessibility), but no quality API equivalent to "automatic level" is exposed to game scripts.

## Free legal VFX resources and upload rules

### Takeaway
The safest zero-cost sources are Roblox's built-in `rbxasset://textures/...` files (no upload needed), CC0 packs such as Kenney's Particle Pack (uploaded as your own images), and textures you draw yourself. Treat Toolbox/Creator Store VFX models as untrusted until every script inside has been inspected or deleted.

### Cited Findings
- Kenney Particle Pack: **CC0** licence, 80 sprites (particles, light cookies, shader textures). Credit to Kenney.nl is optional. — [OpenGameArt: Particle Pack (80 sprites)](https://opengameart.org/content/particle-pack-80-sprites); also CC0 on the [Godot Asset Library entry](https://godotengine.org/asset-library/asset/edit/2649) (GitHub mirror Calinou/kenney-particle-pack)
- Upload limits (official Open Cloud asset usage guide): Decal/Image accepts .png, .jpeg, .bmp, .tga. It "must be smaller than 8000x8000 pixels" and is "not available for updating" (you cannot replace an uploaded image under the same ID). Each API call creates one asset of up to 20 MB. The documented monthly caps apply to **audio** (100 per month ID-verified, 10 per month otherwise), not images. — [Usage guide for assets](https://create.roblox.com/docs/en-us/cloud/guides/usage-assets) (from search summary). Third-party claims of a 1024×1024 or 1 MB cap conflict with this and appear to be low-quality SEO pages.
- Built-in textures: the game already uses `rbxasset://textures/particles/sparkles_main.dds` and `rbxasset://textures/particles/fire_main.dds` (`src/shared/Auras.luau`, lines 15–16). The legacy Sparkles texture dates to around 2010 and Fire/Smoke to around 2014. — [DevForum: Sparkles are outdated](https://devforum.roblox.com/t/sparkles-are-outdated/98057)
- Vetting free models: search all scripts (Ctrl+Shift+F) for `require`, `loadstring`, `getfenv`, `setfenv`, `string.` obfuscation, `luraph`, `IsStudio`, and the reversed string "eriuqer". Code can be hidden behind long indentation or whitespace. Bot-like or brand-new creator accounts are a warning sign. Fake plugins are a common way backdoors get in. Community advice is to use free models only as placeholders. — [DevForum: Removing Backdoors 101](https://devforum.roblox.com/t/removing-backdoors-101/545574), [DevForum: Finding a Backdoor](https://devforum.roblox.com/t/finding-a-backdoor/314003/25), [DevForum: Mysterious Script](https://devforum.roblox.com/t/mysterious-script-in-my-game-o/2986022)
- Free scanner plugin: ShieldScan flags `require(assetId)`, HttpGet, loaders and injectors. It is meant to assist manual review, and flagged scripts are not necessarily malicious. — [DevForum: ShieldScan](https://devforum.roblox.com/t/shieldscan-anti-backdoor-scanner-for-roblox-studio/4736119)

### Inferences
- For this project, the effects are code-built, so a VFX model from the Creator Store is mostly useful as a **texture ID donor**. Insert it into an empty baseplate, copy the `Texture` IDs from its emitters, and delete the model. This avoids importing scripts altogether. (Reusing a texture ID owned by someone else works in practice but carries some risk of later moderation or removal; uploading CC0 images yourself is the more durable option.)
- Self-made textures: draw white or greyscale shapes on a transparent background (heart, star, diamond sparkle, confetti rectangle, soft radial glow) at 128² or 256² in a free tool such as GIMP, Krita or Photopea, then tint them with ParticleEmitter `Color`. One white heart texture covers every heart colour.
- Flipbook sheets must be square powers of two (8–1024) with a little padding per cell, per the release notes above.

### Gaps
- I could not fetch an authoritative full list of built-in `rbxasset://textures/particles/*` files. A search for the directory listing (e.g. the MaximumADHD Roblox-Client-Tracker repo) returned nothing usable. Divyansh can browse `%LOCALAPPDATA%\Roblox\Versions\<version>\content\textures\particles` on Windows to see the actual files (unverified path suggestion).
- I did not confirm the current Creator Store licence terms for using other creators' images.
- Image moderation turnaround times and any per-day image upload cap were not found.

## VFX patterns for fashion, runway and social games

### Takeaway
I found no authoritative technical breakdown of Dress to Impress or Fashion Famous visuals. Secondary sources confirm DTI sells and grants "Runway Effect Packs" as event rewards, so catwalk VFX is an established monetisable layer in the genre. The patterns below are built from Roblox primitives rather than copied from those games.

### Cited Findings
- Dress to Impress's "Runway Chaos" event added Runway Effect Packs for the catwalk. Some were free for players who joined in the first three hours, and others cost Robux. Sources disagree on the date (27 Sep–3 Oct 2025 versus a 2026 date). Lists of "spotlight follows character" and "enhanced lighting" effects were labelled community speculation. — [StealthyGaming: Runway Chaos update](https://stealthygaming.com/dress-to-impress-runway-chaos-update/), [Rosenberry Rooms guide](https://www.rosenberryrooms.com/?p=57902) (secondary sources; only search summaries were read)
- DTI updates (Petal, Halloween) revamped the runway, the dressing room and runway walks. The summaries do not mention lighting changes. — [GameLeap: Halloween update log](https://www.gameleap.com/articles/dress-to-impress-halloween-update-log-everything-new), [Deltia's Gaming: Petal update](https://deltiasgaming.com/?p=192183)

### Inferences (design recommendations mapped to Roblox primitives)
- **Runway key light**: one SpotLight (Shadows on only if affordable) on an attachment that follows the walker, plus a Beam cone from the ceiling. Two or three side Beams can sweep by tweening their attachment CFrames on the client.
- **Paparazzi camera flashes**: small PointLight pulses (Brightness tween to 0 over about 0.1 s) on audience-side attachments, plus a tiny white star particle `Emit(1)` with LightEmission 1. Keep the rate under 3 per second overall, randomise positions, and skip both the lights and any screen flash when the player's flashing setting is off. Show a static "camera" sparkle instead.
- **Sparkle/glitter on outfits**: a low-Rate (about 3–6) emitter with `LockedToPart = true` on the torso and arms, a small Size (0.1–0.3), a flipbook Random mode for twinkle, and `LightInfluence 0` so it reads in dark lighting.
- **Entrance**: a OneShot flipbook or `Emit(30)` ring (Shape = Disc or Cylinder, surface-only) at the runway start, plus `Trail:Clear()` before the walk begins.
- **Item equip "poof"**: `Emit(15–25)` of a soft cloud or star texture at the mannequin, with a short Lifetime (0.4–0.8 s) and a quick Size curve up then fade out.
- **Voting**: star bursts colour-coded by score (`Emit` count scales with the star value). For Hearts mode, rising hearts with VelocityParallel orientation off, a slight upward Acceleration and a Squash wobble.
- **Podium/results**: confetti from 2–3 emitters above the podium (Rate 0, `Emit(40–60)` once or twice; rectangles with VelocityParallel or Rotation and RotSpeed), Highlights on the top three, and an optional firework as a Beam or Trail rising then an `Emit` burst. Don't add any effect that singles out last place (brief constraint).
- **Coins and rank-up**: UI-level effects (TweenService scale pop plus a UIGradient sweep across the banner) are cheaper than 3D particles and stay visible on small phone screens.

### Gaps
- No primary-source (developer) breakdown of DTI or Fashion Famous VFX was found. Video analyses on YouTube were not reachable this session.

## Accessibility: flashing and reduced motion

### Takeaway
Roblox's own accessibility guidelines don't address flashing. WCAG 2.3.1 is the usable standard: no more than 3 flashes in any one-second period, with saturated red treated as more dangerous. Roblox exposes `GuiService.ReducedMotionEnabled`, which the game should respect alongside its own "flashing effects off" setting.

### Cited Findings
- WCAG 2.3.1 (Level A, unchanged across WCAG versions): content must not flash more than **three times in any one-second period** unless the flashes stay below the general flash and red flash thresholds. People are more sensitive to saturated red flashing, and non-compliant content anywhere affects the whole page. — [W3C Understanding SC 2.3.1 (WCAG 2.2)](https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html), [W3C WCAG 2.0 Understanding](https://www.w3.org/WAI/WCAG20/Understanding/three-flashes-or-below-threshold)
- Small-area allowance: flashing in an area of 21,824 square pixels or less passes (based on a 1024×768 screen reference, about 10° of the visual field). — [DAISY KB](https://kb.daisy.org/publishing/docs/wcag/three-flashes-or-below-threshold.html) (secondary; check the W3C page before relying on it). On a phone, a runway shot fills much of the screen, so this allowance rarely helps.
- Epilepsy Foundation guidance, as cited in a lighting document: flash rate under 2 Hz with breaks between flashes. — [South Dakota PUC exhibit citing the Epilepsy Foundation](https://puc.sd.gov/commission/dockets/electric/2019/el19-027/prefiledexhibits/CRWII/A178.pdf) (secondary citation)
- Roblox Accessibility guidelines list `GuiService.PreferredTransparency`, `GuiService.PreferredTextSize` and **`GuiService.ReducedMotionEnabled`** as player preferences to respect. The page has **no guidance on flashing, strobing, photosensitivity or camera shake**. — [Roblox Accessibility guidelines](https://create.roblox.com/docs/production/publishing/accessibility)
- Real-world risk: news reports in 2025–2026 linked a Roblox game ("Doom by Fate") to an alleged seizure death. This is **unconfirmed**, but the game afterwards added a launch warning and removed an effect. — [GosuGamers report](https://www.gosugamers.net/entertainment/news/78238-roblox-game-allegedly-linked-to-player-s-epilepsy-death-developers-criticised-for-negligence)

### Inferences
- Even with flashing on, design every flash to stay at or below about 2–3 per second, game-wide and summed across sources (several paparazzi flashes at once count as one flashing screen). Avoid saturated red full-screen flashes, and avoid disco strobes that flip luminance hard.
- Respect `GuiService.ReducedMotionEnabled` by default: turn off camera shake, sweeping beams and swirling confetti, or reduce them to gentle fades. Consider defaulting the game's flashing setting to off when ReducedMotionEnabled is true.
- Consider a short one-time notice ("This game has flashing lights; turn them off in Settings") on first join. Doing so follows WCAG/industry practice; Roblox does not require it as far as was found.

### Gaps
- I found no Roblox Community Standards or Terms clause specifically about photosensitive content.

## Common mistakes

### Takeaway
The recurring mistakes are creating effects on the server, leaving emitters and Highlights alive, using too many shadow-casting lights, stacking transparent layers, and using oversized textures. Each has a documented cause.

### Cited Findings
- Server-replicated effects are laggy. Validate on the server and render on the client. — [DevForum: client-sided VFX](https://devforum.roblox.com/t/client-sided-vfx/2792835)
- Disabled Highlights still use one of the 255 slots, so destroy them instead. — [Highlight](https://create.roblox.com/docs/reference/engine/classes/Highlight)
- Many shadow-casting lights and dense small shadowed parts cause performance problems. Shadows turn off below quality level 4 anyway, so the effect has to look fine without them. — [Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- Layered transparency causes overdraw. — [Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- Oversized or unique textures waste memory, and flipbooks are auto-disabled on low-memory phones. — [Improve performance](https://create.roblox.com/docs/performance-optimization/improve), [Particle emitters guide](https://create.roblox.com/docs/effects/particle-emitters)
- Changing ParticleEmitter properties frequently can have a "dramatic impact on performance". Avoid tweening emitter properties every frame; prefer pre-configured emitters and `Emit()`. — [Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- Old flipbook enum names (TwoByTwo etc.) in tutorials no longer work. — [Flipbook release](https://devforum.roblox.com/t/particles’-flipbook-release/2029388)
- Cleanup: spawn cosmetic effects on clients and destroy or pool them, e.g. with `Debris:AddItem(obj, seconds)`. — local Roblox skill reference (roblox-world-building); standard practice, no web source fetched.

### Inferences
- Wash-out: `Brightness` above 1 combined with `LightEmission 1` and `LightInfluence 0`, under BloomEffect, quickly turns stacked particles into white blobs, especially in front of the runway camera. Keep Brightness at about 1–2 for additive particles near the camera, and keep bloom subtle.
- Particles parented to a disabled or destroyed part vanish instantly. For a burst that should outlive its source, emit from an anchored invisible part and destroy it after the maximum Lifetime.
- Per-effect cleanup in this codebase: tie every client-created emitter to a round-phase cleanup (Janitor or Maid pattern, or Debris), so effects from the Results phase don't leak into the next Lobby.

### Gaps
- I found no official Roblox numbers for "too many lights" (e.g. a recommended maximum count of non-shadow lights under Future lighting).
