# Roblox lighting and post-processing (state as of October 2026) for "Style My Bestie"

Source access note: create.roblox.com and devforum.roblox.com could not be fetched directly from this
environment. Creator Hub content was read from the official open-source docs repo
(github.com/Roblox/creator-docs, `content/en-us/...`), which is the source of create.roblox.com; each
finding cites the matching create.roblox.com URL, plus the repo file where useful. Property defaults
come from the engine API dump mirrored by Roblox-Client-Tracker (Full-API-Dump.json, fetched
2026-10-20). DevForum posts were read through Firecrawl scrapes or search excerpts, and the notes say
which.

Docs: https://create.roblox.com/docs/... (repo: https://github.com/Roblox/creator-docs/tree/main/content/en-us)
API dump: https://github.com/MaximumADHD/Roblox-Client-Tracker/blob/roblox/Full-API-Dump.json

## 1. Lighting technology: Technology vs LightingStyle / PrioritizeLightingQuality, scripting, mobile

### Takeaway
`Lighting.Technology` (Voxel/ShadowMap/Future) has been **superseded** by two properties:
`LightingStyle` (Realistic | Soft) and `PrioritizeLightingQuality` (bool). Old values map onto them
automatically: Future = Realistic + Prioritize on; ShadowMap = Soft + Prioritize on; Voxel = Soft +
Prioritize off. Legacy, Compatibility and Unified are deprecated and can't be selected in Studio. Set
the lighting mode in Studio's Properties window. Roblox's announcement says scripts can't set it; the
API dump disagrees (see the conflict below). The engine lowers shadow quality as the device's graphics
level drops and turns shadows off completely below quality level 4. Every mobile player will see that
fallback at some point.

### Cited Findings
- `Technology` enum values: Legacy (0, deprecated, "cannot be selected in Studio"), Voxel (1, "Uses a 4×4×4 voxel map for light and shadow calculation"), Compatibility (2, "Simulates the removed legacy technology and is now deprecated… use Voxel Lighting and add a ColorGradingEffect … set to the Retro preset"; cannot be selected in Studio), ShadowMap (3, "shadow mapping that produces more realistic and crisp shadows from sunlight"), Future (4, "the most advanced technology for high-fidelity lighting and shadows"), Unified (5, deprecated, cannot be selected). The enum page says Technology "has been superseded by LightingStyle … and PrioritizeLightingQuality" — [Technology enum](https://create.roblox.com/docs/reference/engine/enums/Technology) ([repo](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/enums/Technology.yaml))
- `Lighting.Technology` property: "This property is non-scriptable and only modifiable in Studio." Its deprecation message says it has been superseded by LightingStyle and PrioritizeLightingQuality. API dump security: Read/Write = RobloxScriptSecurity, so game scripts can't read or write it — [Lighting class](https://create.roblox.com/docs/reference/engine/classes/Lighting); [API dump](https://github.com/MaximumADHD/Roblox-Client-Tracker/blob/roblox/Full-API-Dump.json)
- `LightingStyle` enum: `Realistic` (0) = "The most advanced and realistic lighting and shadows Roblox can deliver"; `Soft` (1) = "A flat, retro-Roblox look with softer lights and shadows" — [LightingStyle enum](https://create.roblox.com/docs/reference/engine/enums/LightingStyle)
- `Lighting.LightingStyle`: "The actual shadowing path also depends on PrioritizeLightingQuality (for example, Soft with that property enabled uses shadow maps rather than voxel lighting)." — [Lighting class](https://create.roblox.com/docs/reference/engine/classes/Lighting)
- `PrioritizeLightingQuality`: "As the rendering quality level reduces, a setting of true prioritizes features such as advanced shadows and high-quality shaders at closer distances, while a setting of false prioritizes view distance. If lighting and shadows are very important to the artistic feel of your game, set this to true." — [Global lighting guide](https://create.roblox.com/docs/environment/lighting)
- Announcement "Let There Be (Unified) Light! Unified Lighting is Fully Live", published 2025-01-21 and updated 2025-07-23. Mapping: Future → Realistic + PrioritizeLightingQuality Enabled; ShadowMap → Soft + Enabled; Voxel → Soft + Disabled. "Soft: … flatter-looking Lighting with diffused shadows and lower contrast… best option for achieving the classic Roblox look." The FAQ says Realistic with Prioritize disabled "will use the 'Future' lighting technology, but with a shorter shading distance". Roblox also says "for all experiences performance will not degrade", and "GPU Light Grid" (previewed at RDC 2023) was de-prioritized in favour of "performance, lighting scalability, and requested improvements like increased light ranges." It states: "Neither of these properties are scriptable, similar to the old Technology property." — [DevForum announcement](https://devforum.roblox.com/t/let-there-be-unified-light-unified-lighting-is-fully-live/3401512) (read via Firecrawl scrape)
- **Conflict on scriptability:** the current API dump gives `LightingStyle` and `PrioritizeLightingQuality` security None and no NotScriptable tag. That suggests scripts can technically assign them now, unlike `Technology`. The Light sources guide still says LightingStyle is "modifiable only in the Properties window for the global Lighting object" — [API dump](https://github.com/MaximumADHD/Roblox-Client-Tracker/blob/roblox/Full-API-Dump.json); [Light sources guide](https://create.roblox.com/docs/effects/light-sources); [announcement](https://devforum.roblox.com/t/let-there-be-unified-light-unified-lighting-is-fully-live/3401512)
- Defaults for a newly constructed Lighting, per the API dump: LightingStyle = Realistic, PrioritizeLightingQuality = true, ShadowSoftness = 0.5, Brightness = 1, ExposureCompensation = 0, Ambient = OutdoorAmbient = (0.5,0.5,0.5), EnvironmentDiffuseScale = 0, EnvironmentSpecularScale = 0, ClockTime = 14, GeographicLatitude = 41.73, FogEnd = 100000. These are reflection defaults; the Baseplate template's saved values can differ — [API dump](https://github.com/MaximumADHD/Roblox-Client-Tracker/blob/roblox/Full-API-Dump.json)
- `ShadowSoftness` runs from 0 (hard) to 1 (soft) and "is only valid when LightingStyle is set to Realistic" (guide). The older class page says it only works under ShadowMap/Future "and the device is capable of rendering shadow maps" — [Global lighting guide](https://create.roblox.com/docs/environment/lighting); [Lighting class](https://create.roblox.com/docs/reference/engine/classes/Lighting)
- Shadow fallback by quality level: "The Roblox engine automatically degrades shadow quality as client graphics quality level decreases, eventually disabling shadows altogether at quality levels below 4." — [Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- Older community and wiki sources say Future and ShadowMap fall back to 4³ voxel shadows on low quality levels and on mobile. One forum post quotes staff: "low graphics settings will automatically fallback to Voxel from ShadowMap to save performance, no matter which you have set". These sources predate 2025 (secondary) — [Future Is Bright wiki](https://roblox.fandom.com/wiki/Future_Is_Bright); [DevForum: mobile lighting mode](https://devforum.roblox.com/t/if-i-care-about-performance-on-mobile-which-lighting-mode-should-i-use/431662) (search excerpt)
- GlobalShadows: with it on, voxel shadows render in sheltered areas, and Ambient applies there while OutdoorAmbient applies outside. "each lighting voxel is 4×4×4 studs. This means objects need to be larger than 4×4×4 studs to display a realistic shadow." With it off, there are no shadows and Ambient applies everywhere — [Lighting class](https://create.roblox.com/docs/reference/engine/classes/Lighting)
- Local light Range is capped at 120 studs. The `ExtendLightRangeTo120` property is "Unused… always 120 studs", non-scriptable and hidden — [Lighting class](https://create.roblox.com/docs/reference/engine/classes/Lighting)
- Compatibility sunset: the announcement (Aug 2024, updated 2024-09-26) says "Voxel is the same code path as Compatibility Lighting and offers the same performance". Compatibility clamped local-light brightness to 1.0. Places were auto-migrated to **Voxel + ColorGradingEffect (Retro)** when opened in Studio, and lights with brightness > 1 "will look brighter in Voxel" — [DevForum: Compatibility → Retro Tone Mapping](https://devforum.roblox.com/t/compatibility-lighting-becomes-retro-tone-mapping-sunset-migration/3128560) (search result with full text)
- Bug reports in 2025 describe Studio or clients that look "forced into Voxel" or show Future looking like Voxel/ShadowMap — [DevForum bug](https://devforum.roblox.com/t/studio-and-client-forced-into-voxel-lighting-technology/3816317); [DevForum bug](https://devforum.roblox.com/t/future-lighting-is-not-working-correctly-and-looks-like-voxel-or-shadowmap/3817698) (titles/excerpts only)

### Inferences
- For a neon indoor venue with about 120 local lights, the intended setting is **LightingStyle = Realistic, PrioritizeLightingQuality = true**. This is the old "Future" mode: per-pixel local lights and specular highlights on marble and glass. Set it once in Studio's Properties window and File > Save to Roblox. Don't depend on a script to set it.
- Low-end phones will drop to voxel-style lighting and lose shadows below quality level 4. The venue still has to read well with **no shadows**: emissive Neon strips, sensible Ambient and readable colours. Shadows can't carry the look.
- If an older version of the place was ever on Compatibility, Studio may have **inserted a ColorGradingEffect set to Retro**. Retro is less saturated and has lower contrast, which could explain part of the "washed out" look. Check Lighting's children in Explorer.

### Gaps
- No official number gives the per-light cost or a maximum light count under Realistic/Future. No official doc gives the exact quality level at which Realistic drops per-pixel local lights on mobile. The "below 4" figure is about shadows.
- No source says whether assigning LightingStyle from a script takes effect at runtime. The API security metadata and the announcement disagree.

## 2. Lighting properties, environment, sky, atmosphere, clouds; newer features

### Takeaway
For interiors, the main controls are **Ambient** (indoor fill), **Brightness** (sun/moon strength),
**ExposureCompensation** (−5…5, ±1 = double/half exposure, applied before tone mapping) and
**EnvironmentDiffuseScale/EnvironmentSpecularScale** (sky light and reflections; both default to 0).
Raising EnvironmentSpecularScale toward 1 is what makes polished marble, metal and glass reflect.
Atmosphere replaces fog. In a closed building it mainly affects views out of windows and the plaza.

### Cited Findings
- Ambient: "lighting hue applied to areas that are occluded from the sky, such as indoor areas." OutdoorAmbient is clamped to be ≥ Ambient per channel — [Lighting class](https://create.roblox.com/docs/reference/engine/classes/Lighting)
- Brightness: "The intensity of illumination in the place… influence the impact of the light source (sun or moon)." The guide shows example values 0.5, 1.5 and 3.75 — [Lighting class](https://create.roblox.com/docs/reference/engine/classes/Lighting); [Global lighting guide](https://create.roblox.com/docs/environment/lighting)
- ExposureCompensation: "applies a bias to the exposure level of the scene prior to the tonemap step. Defaults to 0 … range from -5 to 5. A value of 1 indicates twice as much exposure and -1 means half". The guide's examples are 0, −1 and 1.25 — [Lighting class](https://create.roblox.com/docs/reference/engine/classes/Lighting); [guide](https://create.roblox.com/docs/environment/lighting)
- EnvironmentDiffuseScale: "Ambient light that is derived from the environment… dynamic and can change according to the sky and time of day. When this property is increased, it's recommended to decrease Ambient and OutdoorAmbient accordingly." — [Lighting class](https://create.roblox.com/docs/reference/engine/classes/Lighting)
- EnvironmentSpecularScale: "will make smooth objects reflect the environment and it is especially important to make metal look more realistic". The guide says that near 1, "smooth objects better reflect the environment" — [Lighting class](https://create.roblox.com/docs/reference/engine/classes/Lighting); [guide](https://create.roblox.com/docs/environment/lighting)
- ColorShift_Top/Bottom tint surfaces that face toward or away from the sun or moon. They are scaled by Brightness, and ColorShift_Bottom is "very hard to identify when GlobalShadows is enabled" — [Lighting class](https://create.roblox.com/docs/reference/engine/classes/Lighting)
- ClockTime is NotReplicated in the API dump (it replicates via TimeOfDay). "will not change during gameplay unless it has been changed by a script" — [Lighting class](https://create.roblox.com/docs/reference/engine/classes/Lighting); [API dump](https://github.com/MaximumADHD/Roblox-Client-Tracker/blob/roblox/Full-API-Dump.json)
- Fog properties are hidden when Lighting contains an Atmosphere — [Lighting class](https://create.roblox.com/docs/reference/engine/classes/Lighting)
- Atmosphere properties and defaults (API dump): Density 0.395, Offset 0, Color (200,170,108), Decay (92,60,14), Glare 0, Haze 0. Density "controls how many particles exist in the air"; Offset raises a horizon silhouette or blends distant objects into the sky; Haze is visible above the horizon and into the distance; Glare "must" be combined with Haze > 0; Decay needs Haze and Glare > 0. The guide's examples are Density 0–0.35, Haze 1–2.8 and Color (255,200,255) for pinkish tones — [Atmospheric effects](https://create.roblox.com/docs/environment/atmosphere); [API dump](https://github.com/MaximumADHD/Roblox-Client-Tracker/blob/roblox/Full-API-Dump.json)
- Sky (API dump): SunAngularSize 21, MoonAngularSize 11, StarCount 3000, CelestialBodiesShown, SkyboxOrientation, and new `Skybox*Content`/`SunTextureContent` Content-typed properties alongside the legacy `SkyboxBk/Dn/Ft/Lf/Rt/Up` ID strings — [API dump](https://github.com/MaximumADHD/Roblox-Client-Tracker/blob/roblox/Full-API-Dump.json)
- Dynamic Clouds only render when the `Clouds` object is parented under `Terrain`. Cover (0–1, default 0.5), Density (default 0.7) and Color (default white) are available, and global wind moves them — [Dynamic clouds](https://create.roblox.com/docs/environment/clouds); [API dump](https://github.com/MaximumADHD/Roblox-Client-Tracker/blob/roblox/Full-API-Dump.json)
- The project currently sets ClockTime 17.75 (dusk), GeographicLatitude 35, and Atmosphere Density 0.2, Offset 0, Color (255,200,190), Decay (150,110,170), Glare 0.4, Haze 0.8 — `src/shared/Config.luau` (Config.Environment), `src/server/Lobby/Environment.luau` (repo code, read locally)

### Inferences
- Inside an enclosed building, the sun and OutdoorAmbient hardly matter. Interior brightness comes from **Ambient + local lights + EnvironmentDiffuseScale**. A dusk ClockTime gives little sky light, so a roofed room with Ambient near black looks dark. Raising ExposureCompensation or Bloom to compensate is the usual cause of blown-out neon and "milky" darks. Raise Ambient a little (e.g. a dark plum/charcoal around RGB 40–70) instead of raising exposure. This is my suggestion, not a sourced value.
- For a glossy fashion venue, EnvironmentSpecularScale ≈ 0.5–1 and EnvironmentDiffuseScale ≈ 0.2–0.5 (lowering Ambient to match, per the docs' advice) are reasonable starting points. Tune by eye; these numbers are not from a source.

### Gaps
- I found no 2026 announcement of a new sky, cloud or volumetric lighting feature. The 2025 announcement lists "increased light ranges" as a priority, but I found no shipped change beyond the 120-stud cap.

## 3. Post-processing effects: properties, defaults, Lighting vs Camera, wash-out, per-area presets

### Takeaway
Six PostEffects exist: Bloom, Blur, ColorCorrection, ColorGrading (tone-mapper preset Default or Retro
only), DepthOfField and SunRays. All except ColorGrading work under **Lighting** (all players) or
**Workspace.CurrentCamera** (that player only, which suits per-phase or per-booth looks). Bloom and
Neon glow are the same effect, so Bloom settings decide how hard every Neon strip glows. Some effects
degrade or disappear on low quality levels.

### Cited Findings
- Parenting: effects in Lighting "display to all players"; effects in Camera "only display to a specific player… such as blurring the 3D world view when they have a UI menu open." — [Post-processing effects](https://create.roblox.com/docs/environment/post-processing-effects)
- PostEffect base: effects change the world "after it has been rendered. They do not affect GuiObjects." "some post-processing effects will work differently or **not at all** when Roblox is set to a low QualityLevel… On some low-end devices, faster rendering algorithms may be used." — [PostEffect](https://create.roblox.com/docs/reference/engine/classes/PostEffect)
- **ColorGradingEffect** "is expected to be parented to Lighting and will be ignored if parented elsewhere. Multiple instances cannot be combined and only the most recently parented instance to Lighting will be applied." Its only property is TonemapperPreset: `Default` = "post-2019 Roblox appearance which provides vivid colors and high contrasts"; `Retro` = "imitate the pre-2019 Roblox appearance. Colors look less saturated and there is less contrast". For a full pre-2019 look, also cap light brightness at 1.0 — [ColorGradingEffect](https://create.roblox.com/docs/reference/engine/classes/ColorGradingEffect); [TonemapperPreset](https://create.roblox.com/docs/reference/engine/enums/TonemapperPreset); [Post-processing effects](https://create.roblox.com/docs/environment/post-processing-effects)
- **BloomEffect**: "causes brighter colors to glow, similar to applying the neon Material to everything, including the Sky. Multiple BloomEffect objects… compose their effects together." Intensity = additive blend strength; Size = radius in pixels (0 disables the bleed but not the colour adjustment); Threshold: "If set to 1, only pure white colors will bloom. If set to 0, all colors will bloom." Defaults (API dump): Intensity 0.4, Size 24, Threshold 0.95 — [BloomEffect](https://create.roblox.com/docs/reference/engine/classes/BloomEffect); [API dump](https://github.com/MaximumADHD/Roblox-Client-Tracker/blob/roblox/Full-API-Dump.json)
- Neon glow and bloom: "Bloom and Neon are the same post-effect. You can set Threshold to 1 on Bloom to suppress the blooming of bright pixels." To dim neon, "increase its Threshold property, or lower its size / intensity". These are DevForum replies seen as search excerpts. The 2018 "Unified Neon and Bloom" poll thread describes the bloom slider becoming the "neon intensity slider" — [Adjustable Glow Effect for Neon](https://devforum.roblox.com/t/adjustable-glow-effect-for-neon/59089); [Neon material too bright](https://devforum.roblox.com/t/neon-material-too-bright/2497344); [Unified Neon and Bloom poll](https://devforum.roblox.com/t/unified-neon-and-bloom-poll/180359)
- **ColorCorrectionEffect**: Brightness (−1 all black … 1 all white), Contrast (<0 less, >0 more), Saturation (−1 fully desaturated … >1 more vivid in the docs' wording; above 0 increases), TintColor (multiplicative per channel; red (255,0,0) zeroes green and blue). Multiple instances compose. Defaults: 0/0/0, Tint white — [ColorCorrectionEffect](https://create.roblox.com/docs/reference/engine/classes/ColorCorrectionEffect); [API dump](https://github.com/MaximumADHD/Roblox-Client-Tracker/blob/roblox/Full-API-Dump.json)
- **DepthOfFieldEffect**: FocusDistance (studs from camera), InFocusRadius (studs on both sides with no blur), NearIntensity and FarIntensity. Defaults: FarIntensity 0.75, FocusDistance 0.05, InFocusRadius 10, NearIntensity 0.75. It "may render differently on low-end devices" — [DepthOfFieldEffect](https://create.roblox.com/docs/reference/engine/classes/DepthOfFieldEffect); [API dump](https://github.com/MaximumADHD/Roblox-Client-Tracker/blob/roblox/Full-API-Dump.json)
- **SunRaysEffect**: Intensity (opacity, 0–1), Spread (0–1; outside that range is undefined). Defaults: 0.25 and 1. It "may not render on low-end devices" — [SunRaysEffect](https://create.roblox.com/docs/reference/engine/classes/SunRaysEffect)
- **BlurEffect**: Size = radius in pixels, default 24. "Only one BlurEffect can be applied at once (the instance with the greatest Size takes priority)." — [BlurEffect](https://create.roblox.com/docs/reference/engine/classes/BlurEffect)
- Studio preview: some effects may not show unless Studio Settings > Rendering > Editor Quality Level is at the highest level — [Post-processing effects](https://create.roblox.com/docs/environment/post-processing-effects)
- Community values (forum excerpts, not official): a cartoony look with ColorCorrection Brightness 0.03, Saturation 0.3, Contrast 0.1 — [What are some good lighting settings?](https://devforum.roblox.com/t/what-are-some-good-lighting-settings/204507); Bloom Intensity 0.1, Size 0.4 (likely a typo for a larger value), Threshold 0.8 — [Hyper realistic Lighting Settings?](https://devforum.roblox.com/t/hyper-realistic-lighting-settings/915802)
- Project state: `src/client/Stage.luau` disables Bloom, ColorGrading, ColorCorrection, SunRays, DoF and Blur under Lighting while styling. Its comment: "They can wash a bright scene out to white; the booth needs true colours." `src/server/Round/Map.luau` dropped the booth roof because "an enclosed dark room looked washed out with the place's Bloom/ColorGrading" (repo code, read locally)

### Inferences
- **Why rooms washed out:** with a low Threshold (well under 1), bloom adds glow to ordinary lit pixels, so mid-tones turn milky. A Retro ColorGradingEffect also lowers contrast and saturation, and positive ColorCorrection Brightness lifts blacks toward grey. Together these explain the washed-out booths. To fix it: keep Threshold high (about 0.9–1.5; values above 1 bloom only HDR-bright pixels such as Neon and strong lights), keep Intensity modest (about 0.3–0.8), Size about 16–32, set ColorGrading to **Default** (or delete it), and keep ColorCorrection Brightness at about 0–0.05 with Contrast about 0.05–0.15 and Saturation about 0.05–0.2. These ranges are my synthesis of the documented semantics, not official presets. "Inverted"-looking colours fit a strong TintColor or a negative Saturation/Contrast, so check every ColorCorrectionEffect in Lighting and on the Camera.
- **Per-phase presets:** keep the global set in Lighting gentle. Put phase-specific effects on `Workspace.CurrentCamera` from the client (e.g. a runway preset with stronger bloom and contrast, a styling-booth preset with neutral colour and no bloom, Blur on menus) and tween their properties with TweenService. That is cleaner than disabling Lighting effects, and it only affects the local player. ColorGradingEffect is the exception: it only works in Lighting, and only one counts.
- Every Bloom instance in Lighting and on the Camera composes, so a client Camera bloom stacks with the Lighting bloom. Use ColorCorrection to neutralise (or tween Lighting bloom down) instead of adding another bloom.

### Gaps
- I found no official recommended values for Bloom or ColorCorrection. The docs only describe ranges.
- I found no official doc on whether Roblox applies auto-exposure or eye adaptation. Don't assume it does.
- No LUT or custom colour-grading options exist as of these sources. Only the Default and Retro tonemapper presets are documented.

## 4. Presets for glamorous / neon / night-club / fashion venues; what top fashion games look like

### Takeaway
Roblox publishes no "fashion" or "night club" preset, and I found no reliable source describing
Dress to Impress's actual lighting settings. Community advice repeats the same pattern: Realistic
(Future) lighting, Neon parts with moderate bloom, a subtle saturation and contrast lift, and coloured
local lights instead of heavy exposure.

### Cited Findings
- The Light sources guide pitches local lights for "cyberpunk cities, traditional light festivals, and moody detective scenes". SurfaceLight is "ideal for lighting from computer screens, billboards, signs, and fluorescent panels"; SpotLight for directional lamps (Angle max 180) — [Light sources](https://create.roblox.com/docs/effects/light-sources)
- Neon brightness is controlled through BloomEffect (Threshold/Size/Intensity); see section 3 — [Neon material too bright](https://devforum.roblox.com/t/neon-material-too-bright/2497344)
- A 2026 community tutorial (obby.fun, Oct 2026) and others repeat that older "Technology" tutorials are outdated in favour of LightingStyle/PrioritizeLightingQuality (search summary only) — [obby.fun realistic lighting](https://www.obby.fun/blog/roblox-studio-realistic-lighting)
- Searches for Dress to Impress lighting returned only player TikToks and YouTube outfit videos ("lighting fix tips" for outfits), with no developer-side settings — [TikTok example](https://www.tiktok.com/@allybastaa/video/7659162881702808846)

### Inferences (suggested starting presets; unsourced, tune in Studio)
- **Lobby/venue (global, in Lighting):** LightingStyle Realistic, PrioritizeLightingQuality true, ShadowSoftness 0.2–0.4, Brightness 1–2, ExposureCompensation 0 to −0.3, Ambient about RGB(50,40,60), OutdoorAmbient about RGB(120,100,130), EnvironmentDiffuseScale 0.3, EnvironmentSpecularScale 0.8; Bloom Intensity 0.5, Size 24, Threshold 1.0; ColorCorrection Saturation 0.1, Contrast 0.1, Brightness 0; ColorGrading Default or none.
- **Runway (client Camera overlay during Runway):** tween ColorCorrection Contrast to about 0.2 and Saturation to about 0.2, and Lighting bloom Intensity up to about 0.8. Keep Threshold ≥ 0.95 so spotlit outfits don't bleach. Optionally add DoF on the podium/lineup camera (FocusDistance = distance to the model, InFocusRadius about 6–10, FarIntensity about 0.3).
- **Styling booth (client Camera overlay):** a neutral ColorCorrection (counter-tint if needed), bloom effectively off (tween Lighting bloom Intensity to 0 or Threshold to 2+), bright neutral lighting (a white SurfaceLight or PointLight over the mannequin). Outfit colours stay true, and the global look doesn't need disabling.
- **Mood colours for "glamorous":** magenta/pink and cyan/violet neon accents, warm white (about RGB 255,230,210) key spotlights on the runway so skin and clothes read correctly, and coloured lights kept for walls and floors instead of models.

### Gaps
- No verifiable source exists for Dress to Impress's or other top fashion games' Lighting values. Any claim about them would be speculation.

## 5. Materials and surfaces under Realistic/Future lighting; imported MeshParts

### Takeaway
Neon is self-lit and glows through bloom, which suits LED strips. Glass refraction **does not work on
mobile**. Smooth, low-roughness surfaces (SmoothPlastic, Marble, Glass, Foil/Metal) only reflect when
EnvironmentSpecularScale is above 0. MaterialVariant (tileable PBR) and SurfaceAppearance (per-mesh
PBR) are free to make in Studio, and SurfaceAppearance supports emissive masks.

### Cited Findings
- "Refraction of light through the glass material is not supported on mobile devices due to computational limitations." — [Materials](https://create.roblox.com/docs/parts/materials) (footnote ³)
- MaterialVariant is "for customizing the appearance of reusable tileable material", while SurfaceAppearance is "for customizing the visual appearance of a specific mesh with UV mapping". Both use PBR textures, and MaterialVariants carry physical properties. They live in MaterialService, can be made in Material Manager or with the prompt-based Material Generator, and the Creator Store has a Materials category for material packs — [Materials](https://create.roblox.com/docs/parts/materials)
- SurfaceAppearance supports 5 PBR maps (color, normal, roughness, metalness, emissive). The emissive mask works with `EmissiveStrength` and `EmissiveTint`. Advice: "Avoid adjusting material values to look better in one specific lighting situation." — [PBR textures](https://create.roblox.com/docs/art/modeling/surface-appearance)
- EnvironmentSpecularScale makes smooth objects reflect the environment (see section 2) — [Lighting class](https://create.roblox.com/docs/reference/engine/classes/Lighting)
- Performance: "Avoid transparency values other than 0 (visible) and 1 (invisible)", and avoid layered transparency (overdraw) — [Performance design](https://create.roblox.com/docs/performance-optimization/design); [Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- In the MaterialService bug thread, a lighting mismatch between two places came from a MaterialService setting, not from lighting (search summary) — [Same lighting in 2 games, but one is brighter](https://devforum.roblox.com/t/same-lighting-in-2-games-but-one-is-brighter/3883177)

### Inferences
- Glass capsules: on mobile they render without refraction, so they need to look fine as plain tinted transparency. Use one transparency layer (for example 0.5–0.7) and don't stack glass parts.
- Imported MeshParts take whatever `Material` the import or `BlendImport.apply()` assigns. The project already styles pieces from `BlendData` materials. For LED strips, use `Enum.Material.Neon` with a saturated colour. Use Marble or SmoothPlastic for floors, with a Reflectance of about 0.05–0.2 if needed (an unsourced suggestion) plus EnvironmentSpecularScale. Metal or Foil suits trims.
- SurfaceAppearance emissive masks give per-pixel glowing signage without adding Light objects, and they add no light cost.

### Gaps
- I didn't find an official statement on the relative render cost of each material or of SurfaceAppearance on mobile.

## 6. Mobile performance: lights, shadows, quality levels, streaming

### Takeaway
Shadow-casting lights and many small shadow casters are the expensive part. Roblox's own advice is to
turn off `Light.Shadows` where you don't need them, set `CastShadow = false` on small or distant parts,
limit light Range and Angle, use fewer lights, and turn lights off room by room. With about 120 lights,
almost none should cast shadows. Keep shadows for the few runway spotlights at most.

### Cited Findings
- "Excessive shadow casting - Handling shadows is an expensive process, and maps that contain a high number and density of light objects that cast shadows (or a high number and density of small parts influenced by shadows) can have performance issues." — [Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- Mitigations quoted from the docs: "Use the BasePart.CastShadow property to disable shadow casting on small parts where shadows are unlikely to be visible" (may cause shadow artifacts); "Disable shadows on moving objects when possible"; "Disable Light.Shadows on light instances where the object does not need to cast shadows"; "Limit the range and angle of light instances"; "Use fewer light instances"; "Consider disabling lights that are outside of a specific range or on a room-by-room basis for indoor environments." Doing this also "increase[s] the likelihood that shadows remain enabled." — [Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- MicroProfiler scopes for lighting: `Perform/Scene/computeLightingPerform` (light grid and shadow updates), `LightGridCPU` (voxel light grid updates), `ShadowMapSystem` (shadow mapping) — [Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- Light Brightness is "still limited to the light's defined range, so a higher Brightness value doesn't light up a larger region" — [Light sources](https://create.roblox.com/docs/effects/light-sources)
- Lights must be a direct child of a BasePart or Attachment in Workspace to emit; Attachment is recommended for PointLight — [PointLight](https://create.roblox.com/docs/reference/engine/classes/PointLight); [Light sources](https://create.roblox.com/docs/effects/light-sources)
- Streaming: instance streaming "improves join times, reduces memory footprint, and increases frame rate". With streaming, Model.LevelOfDetail = SLIM and Workspace.EnableSLIMAvatars render lightweight distant versions — [Performance design](https://create.roblox.com/docs/performance-optimization/design); [Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- RenderSettings.QualityLevel/EditQualityLevel are PluginSecurity, and UserGameSettings.GraphicsQualityLevel is RobloxScriptSecurity. A game script can't force or read the player's graphics level (SavedQualityLevel is readable; security None) — [API dump](https://github.com/MaximumADHD/Roblox-Client-Tracker/blob/roblox/Full-API-Dump.json)
- A community builder's claim (Nov 2024, not staff): "ShadowMap technology will unequivocally tower over Future lighting technology when it comes to performance." The thread's author says Future felt "unplayable for mobile devices with under 2gb of RAM" — [Future vs Shadowmap performance](https://devforum.roblox.com/t/future-vs-shadowmap-performance/3246937) (Firecrawl scrape)
- The 2025 Unified Lighting announcement claims "performance will not degrade" after migration and that Prioritize disabled trades lighting quality first — [announcement](https://devforum.roblox.com/t/let-there-be-unified-light-unified-lighting-is-fully-live/3401512)

### Inferences
- With about 120 Blender-converted lights: set `Shadows = false` on all of them except 2–4 hero runway SpotLights. Clamp Range to what each light needs (most LED-strip fill lights can run 8–16 studs), and consider turning off lights in areas the player can't see (hall of fame, VIP lounge, shop) with client-side proximity or zone checks. Set `CastShadow = false` on small decor meshes, LED strips, glass capsules and Neon parts.
- If profiling on a phone shows lighting as the bottleneck, `PrioritizeLightingQuality = false` makes the engine scale lighting down before draw distance. For a compact indoor venue, draw distance matters less, so keeping it `true` is likely the better trade. Test both on a real phone with the MicroProfiler scopes above.
- Since scripts can't read the graphics level, any "low-quality mode" must be a player-facing toggle in Settings (the game already has a Settings UI), for example one that turns off Camera-side bloom and DoF and some decorative lights.

### Gaps
- Roblox hasn't published numbers for how many lights or shadow-casting lights a mobile device can handle under Realistic. Only the qualitative guidance above exists.
- No measured effect of StreamingEnabled on lighting cost specifically; the docs only state general frame-rate and memory gains.
