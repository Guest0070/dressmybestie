# Free and legal SFX and music for a Roblox game (state as of Oct 2026)

Scope: free and legal audio for "Style My Bestie" (Roblox fashion/runway game, zero budget, mobile-first).
The code already uses classic `Sound` + SoundGroups (Music, SFX) with `rbxasset://sounds/...` placeholders
(`src/client/Audio.luau`, `src/client/UI/Kit.luau`, `src/client/MinigameFx.luau`,
`src/server/Lobby/Minigames/Arena.luau`). Slots: Click, PhaseChange, Heart, Podium, LobbyMoment, Reaction,
Alert, RunwayMusic, LobbyMusic.

Research note: create.roblox.com docs were fetched as live `.md` pages (dated 2026-10-20). Several
secondary sites could not be fetched (DNS failures). Those findings come from search-result summaries and
are marked as such.

## Rules for audio on Roblox in 2025-2026 (privacy, permissions, what plays where)

### Takeaway
Two sources are safe at zero cost: free-to-use Creator Store audio (Roblox and partner audio, 100,000+
professional tracks and SFX) and audio you upload yourself, which is free. Audio you upload always plays in
your own games. Someone else's private audio plays only if its owner grants your experience permission.
A sound blocked by permissions fails to load and leaves a clickable error in the Output window.

### Cited Findings
- **Current:** the Creator Store tab of the Toolbox "contains a wide variety of free-to-use audio assets made by Roblox and the Roblox community... including more than 100,000 professionally-produced sound effects and music tracks from top audio and music partners." — [Roblox Docs: Audio assets](https://create.roblox.com/docs/en-us/audio/assets.md)
- **Current:** after moderation you can reuse uploaded audio "in any project on the platform." At first only you can view and use private audio. The asset privacy system lets you grant usage to specific friends and experiences. — [Roblox Docs: Audio assets](https://create.roblox.com/docs/en-us/audio/assets.md)
- **Current:** asset access is either **Restricted** (only usable after the owner grants permission) or **Open Use** (any creator or game). If a creator or game lacks permission, the asset "cannot load in Studio, and a clickable error message displays in the Output window." If the creator has permission but the game doesn't, clicking the error opens a pop-up to grant the game permission. — [Roblox Docs: Asset privacy](https://create.roblox.com/docs/en-us/projects/assets/privacy.md)
- **Current:** the newer Creator Dashboard "Asset Privacy" opt-in toggle covers only Images, Decals and Meshes. "Audio, Video, Models, MeshParts, Animations, and Packages... have their own creation defaults... If audio... [is] not loading... Asset Privacy is not the cause." "Using your own assets in your own published games" always works. — [Roblox Docs: Asset privacy](https://create.roblox.com/docs/en-us/projects/assets/privacy.md)
- **Current, irreversible actions:** Open Use cannot be changed back to Restricted, and a permission granted to a game cannot be revoked. — [Roblox Docs: Asset privacy](https://create.roblox.com/docs/en-us/projects/assets/privacy.md)
- **Current, granting access:** go to Creator Dashboard > Development Items > Audio > (asset) > Permissions > Experiences tab > Add experiences > enter the Universe ID. Alternatively, open the game > Configurations > Permissions and paste the asset IDs, comma-separated. Granting to an individual creator requires that they are your Roblox friend. A restricted asset used from a script needs the game itself to have permission, "otherwise the asset is not visible or audible during runtime." — [Roblox Docs: Asset privacy](https://create.roblox.com/docs/en-us/projects/assets/privacy.md)
- **HISTORICAL (March 2022):** Roblox announced that "On March 22, all new audio uploaded will be Private and all existing audio longer than 6 seconds will be set to Private." In the same change, uploads became free with monthly limits (the example given was 100 per month for ID-verified accounts), and Roblox shipped an Audio Discovery plugin to review the ownership of audio in an experience. — [DevForum announcement](https://devforum.roblox.com/t/1701697) (via search summary); coverage at [Pro Game Guides](https://progameguides.com/roblox/roblox-to-private-millions-of-user-created-sounds-within-its-audio-database/). Secondary articles overstated the scope ("nearly all audio"). The primary post limits the retroactive change to existing audio over 6 seconds.
- **HISTORICAL (June 2018):** Roblox began removing and blocking unlicensed copyrighted music from June 18, 2018. Uploading music you don't own or license is against the Terms of Use. — [Roblox Support: Using Licensed Music](https://en.help.roblox.com/hc/articles/360000927163)

### Inferences
- For Divyansh, the safe rule is: use only (a) Creator Store audio published by Roblox or a partner, or marked free-to-use, or (b) files he uploads himself from a CC0 or royalty-free library. Random IDs copied from YouTube lists or old "music code" sites are mostly private since 2022 and will fail silently in game. The failure shows only as an Output error.
- To check a sound before shipping, paste the ID into a Sound in Studio, press Play in the Properties panel or start a Play test, and watch Output for a load or permission error. In code, `Sound.IsLoaded` / `Sound.Loaded` confirm the load ([Sound reference](https://create.roblox.com/docs/en-us/reference/engine/classes/Sound.md)).
- Upload the place and its audio under the same owner (his user account, or the same group) so no permission grants are needed. If the game moves to a group later, the audio uploaded under his user account needs explicit grants to that experience.

### Gaps
- I couldn't load the full current text of the 2022 DevForum post. The numbers above come from a search summary of it.
- I found no official doc on the current default privacy for a newly uploaded audio asset beyond "initially private to you".

## Roblox licensed music catalog (APM, Monstercat, DistroKid, Too Lost)

### Takeaway
Licensed partner tracks in the Creator Store are royalty-free inside Roblox experiences. Roblox has handled
sync, master, mechanical and performance licensing. Limits: at most 250 licensed tracks per game, use only on
Roblox, no downloading or exporting, and no streaming-service-style features. Recording videos with licensed
music has its own help article, which I could not read.

### Cited Findings
- Roblox's agreement with APM Music gives access to "hundreds of thousands of tracks" that are "royalty free for use on the Roblox platform." Roblox has "taken care of the licensing for you so you don't have to worry about synchronization, master use, mechanical, and performance licenses." — [Roblox Support: Using Licensed Music](https://en.help.roblox.com/hc/articles/360000927163)
- Restrictions: "up to 250 licensed tracks at a time in a single game," including boombox tracks. Derivative works through Studio sound properties are allowed "solely within your game on Roblox." Licensed Music "can only be used on the Roblox platform and may not be downloaded." — [Roblox Support: Using Licensed Music](https://en.help.roblox.com/hc/articles/360000927163)
- The same help page links a separate article, "Using Licensed Music in Videos", for the rules on videos. — [Roblox Support](https://en.help.roblox.com/hc/articles/360000927163)
- DistroKid partnership (announced RDC, Sept 2024): about 180,000 DistroKid tracks added to the Creator Store. Opted-in artists grant "rights for Roblox developers to use [their] music on a gratis basis", and they receive no royalties. — [Music Business Worldwide](https://www.musicbusinessworldwide.com/roblox-strikes-deal-with-distrokid-but-indie-artists-wont-be-paid-any-money-from-it1); [RouteNote](https://routenote.com/blog/roblox-sign-deal-with-distrokid-indie-artists-to-be-unpaid/); [Pocket Tactics RDC 2024](https://www.pockettactics.com/roblox/rdc-2024-music)
- Too Lost (independent distributor) has also partnered with Roblox and added "thousands" of tracks to the Creator Store. Developers can use them in "sound objects, jukeboxes, and background music systems." — [Music Business Worldwide](https://www.musicbusinessworldwide.com/too-lost-partners-with-roblox-to-bring-catalog-of-independent-music-to-games-and-virtual-spaces/) (search summary; I did not confirm the year of the "July 27" date)
- Roblox runs a Music Top 100 chart limited to music licensed for the platform (DistroKid and production-music partners). — [Music Week](https://musicweek.com/digital/read/roblox-launches-top-100-chart-featuring-music-on-the-platform/091037)
- Monstercat: a DevForum feature request mentions a Roblox–Monstercat partnership "to bring more music... for developer use." — [DevForum](https://devforum.roblox.com/t/add-newer-apm-music/279482) (search summary)
- Songs you upload are auto-classified as **sound effect** or **song**. A song can appear on the game's details page (with a 15-second preview) if the uploader is ID-verified, it passes moderation and copyright checks, meets duration, play-count and age requirements, has a meaningful title, and the uploader accepted the Audio Upload License Agreement. The Configure page toggles this. — [Roblox Docs: Audio assets](https://create.roblox.com/docs/en-us/audio/assets.md)

### Inferences
- RunwayMusic and LobbyMusic can come straight from the Creator Store "Music" results by Roblox or partners, at zero cost and with no upload. Search for genre words such as "fashion", "runway", "house", "pop", "catwalk", "upbeat", "lounge" and "chill".
- The 250-track cap won't matter for this game, which needs about 2 to 6 music tracks.
- YouTubers who record the game with licensed music in the background are covered by the separate video article. Check it before encouraging content creators.

### Gaps
- I couldn't read "Using Licensed Music in Videos", so its terms (for example, whether YouTube Content ID claims can happen) are unconfirmed.
- I found no primary source for Monstercat's current catalog size or terms on Roblox.
- No source said whether licensed tracks may be used in Roblox video ads or Sponsored Experiences.

## Uploading your own audio: limits, cost, formats, moderation, free libraries

### Takeaway
Uploading is free. The limit is 2,000 audio imports per 30 days if ID-verified and 100 if not, which is
plenty. Files must be mp3, ogg, wav or flac, under 20 MB and under 7 minutes, at 48 kHz or less, mono or
stereo. For source files, Kenney (CC0) is the simplest. Freesound and OpenGameArt need a per-file licence
check. Pixabay and the Sonniss GDC bundles allow commercial game use without attribution, with resale and
AI-training caveats.

### Cited Findings
- **Current requirements:** you must have the legal rights to the audio, and it must follow the Community Rules and Terms of Use. It must be a single track or stream in `.mp3`, `.ogg`, `.wav` or `.flac`, "less than 20 MB in size and 7 minutes in duration," with a sample rate of 48 kHz or less, and mono, stereo 2.0, 3.0 or 5.1 channels. — [Roblox Docs: Audio assets](https://create.roblox.com/docs/en-us/audio/assets.md)
- **Current limits:** "If you're ID verified, you can import 2,000 free audio assets per 30 days; if you're unverified, you can import 100 free audio assets per 30 days." Any daily limit is replaced by this monthly one. — [Roblox Docs: Audio assets](https://create.roblox.com/docs/en-us/audio/assets.md). Older doc versions and the 2022 post said 100 (verified) and 10 (unverified). These figures are **historical** ([search summary of older docs and DevForum](https://devforum.roblox.com/t/1701697)).
- **How to upload:** in Studio, Asset Manager > Import. Or Creator Dashboard > Development Items > Audio > Upload Asset (name and description required). Or the Open Cloud Assets API. Studio transcodes uploads and rejects corrupt or invalid files. Some older audio tools write invalid headers, so re-export from an up-to-date tool if an import fails. Uploads enter a moderation queue and are visible only to the uploader until approved. — [Roblox Docs: Audio assets](https://create.roblox.com/docs/en-us/audio/assets.md)
- **Kenney:** audio packs are CC0, with no attribution needed and a consistent house style (the UI audio set is designed as one set). — secondary: [Cinevva guide 2026](https://app.cinevva.com/guides/free-sound-effects-music) (search summary)
- **Freesound:** the licence is set per sound (CC0, CC-BY or CC-BY-NC). CC-BY requires credit. CC-BY-NC is unsafe for a monetised game. One guide claims about 72% of sounds are CC0. — secondary: [Cinevva guide](https://app.cinevva.com/guides/free-sound-effects-music) (search summary; the 72% figure is unverified)
- **OpenGameArt:** mixed licences, including CC0, CC-BY and CC-BY-SA. CC-BY-SA is a share-alike obligation and is risky for a commercial game. Filter for CC0. — secondary: [Cinevva guide](https://app.cinevva.com/guides/free-sound-effects-music) (search summary)
- **Pixabay:** sound effects and music are free for commercial and non-commercial use, and attribution is optional. The Terms prohibit selling or distributing the content "on a Standalone basis." — [Pixabay Terms of Service](https://pixabay.com/service/terms/); [Pixabay FAQ](https://pixabay.com/service/faq/) (search summary)
- **Sonniss GameAudioGDC bundles:** free yearly giveaways (the 2026 bundle is 7.47 GB+). Royalty-free, commercial use, no attribution, unlimited projects. The 2024 licence bars using the files to train AI models. — [rekkerd.org (2026 bundle)](https://rekkerd.org/sonniss-releases-gdc-2026-game-audio-bundle/); [GameFromScratch (2024)](https://gamefromscratch.com/sonniss-27-5gb-sound-effect-giveaway-at-gdc-2024/)

### Inferences
- **Zero-budget pipeline:** download CC0 or royalty-free files, trim and normalise them in Audacity (free), export `.ogg` or `.mp3` mono at 44.1 or 48 kHz for SFX, upload through Asset Manager, then paste the IDs into `Config.Sounds`.
- Keep a `research_notes` or `assets/audio/LICENSES.md` log of source URL and licence per file. This is useful proof if a copyright claim ever comes in.
- **Avoid:** CC-BY-NC (the game sells products), CC-BY-SA, "free for YouTube" music, AI music services with unclear rights, and anything ripped from commercial songs.
- **Nothing here costs money.** Paid only: Epidemic Sound, Artlist and similar subscriptions, which are not needed.

### Gaps
- I couldn't fetch the Kenney, Freesound or OpenGameArt licence pages directly (DNS failures). Verify per pack and per file before upload.
- I didn't confirm whether the 2026 Sonniss licence keeps the AI-training clause.
- I found no current figure for typical audio moderation turnaround time.

## Finding, previewing and copying an audio asset ID in Studio

### Takeaway
Open Toolbox > Creator Store tab > category dropdown "Audio", search and filter, then right-click a result
and choose "Copy Asset ID". A left-click inserts a `Sound` into the Explorer instead.

### Cited Findings
- Steps: "In the Toolbox, navigate to the Creator Store tab, then use the category selector dropdown to select Audio." Use keyword search, quick filters and advanced filters. "Right-click any audio asset, then select Copy Asset ID." — [Roblox Docs: Audio assets](https://create.roblox.com/docs/en-us/audio/assets.md)
- "If you click any audio asset, Studio inserts it as a new Sound instance into the Explorer window." — [Roblox Docs: Audio assets](https://create.roblox.com/docs/en-us/audio/assets.md)
- To use your own uploaded or restricted audio, insert it from the Toolbox Inventory or Creations tabs, or paste the ID into the Properties window. — [Roblox Docs: Asset privacy](https://create.roblox.com/docs/en-us/projects/assets/privacy.md)

### Inferences
- In this codebase the ID goes into `Config.Sounds.<Slot>` as a number. `Kit.playSound` and `Audio.luau` then wrap it as `rbxassetid://<id>`, as seen in the source.
- Toolbox audio results have an inline play/preview button. The fetched doc text didn't mention it (see Gaps).

### Gaps
- The fetched docs don't describe the exact current preview UI (play button, duration display, filter names). Divyansh should confirm on screen.

## New Audio API vs classic Sound/SoundGroup; mixing, ducking, preloading, mobile

### Takeaway
The Audio API (`AudioPlayer` → `Wire` → `AudioFader` / effects → `AudioDeviceOutput`, with `AudioEmitter`
and `AudioListener` for 3D) is the current system and is required for sidechain ducking via
`AudioCompressor`. Classic `Sound` still works and is fine for a simple game. The existing code can keep
SoundGroups. Switch only for a concrete benefit such as music ducking, and then switch a whole feature at once.

### Cited Findings
- The Audio API objects: `AudioPlayer` (plays an asset), `AudioEmitter` (virtual speaker), `AudioListener` (virtual mic), `AudioDeviceOutput` (speaker or headphones), `AudioDeviceInput`, `AudioTextToSpeech`, `AudioSpeechToText`, and `Wire`, which carries streams between them. Effects such as `AudioEqualizer`, `AudioCompressor` and `AudioReverb` modify streams non-destructively. — [Roblox Docs: Audio](https://create.roblox.com/docs/en-us/audio.md)
- The docs warn that Toolbox-inserted `Sound` objects "don't have the same dynamic functionality as AudioPlayer objects," and they tell you to paste copied IDs into an `AudioPlayer`. — [Roblox Docs: Audio assets](https://create.roblox.com/docs/en-us/audio/assets.md)
- `AudioCompressor` has Input and Sidechain pins. When wires feed the Sidechain pin, the threshold analyses those streams, so one stream can duck another. The official sample ducks ambience under an explosion. — [AudioCompressor reference](https://create.roblox.com/docs/reference/engine/classes/AudioCompressor) (search summary). Historical: the legacy `CompressorSoundEffect` gained a `SideChain` property for the same purpose ([DevForum](https://devforum.roblox.com/t/compressorsoundeffect-sidechain/30519)).
- SoundGroup volume is a multiplier (a 0.5 sound in a 0.5 group plays at 0.25). A Sound joins a group by setting `Sound.SoundGroup`, not by parenting. — [SoundGroup reference](https://create.roblox.com/docs/reference/engine/classes/SoundGroup) (search summary)
- SoundGroups don't apply to the new Audio API. The equivalent is an `AudioFader` per bus, and wiring many players' sounds through one fader causes routing surprises. — [DevForum: Help with new Audio API](https://devforum.roblox.com/t/help-with-new-audio-api/3799253) (search summary; the thread is unresolved)
- Classic Sound properties: `RollOffMode` controls distance attenuation for a Sound parented to a BasePart or Attachment. `PlaybackSpeed` changes speed and pitch. `IsLoaded` / `Loaded` show when the asset is ready. `PlayOnRemove` plays the sound when it is removed. — [Sound reference](https://create.roblox.com/docs/en-us/reference/engine/classes/Sound.md)
- A third-party skill page claims the docs now discourage Sound, SoundGroup and SoundEffect in favour of audio objects. I couldn't confirm this on the Roblox Sound reference page I fetched, which showed no such note. — [skills.sh page](https://www.skills.sh/tabooharmony/roblox-brain/roblox-audio) (unverified) vs [Sound reference](https://create.roblox.com/docs/en-us/reference/engine/classes/Sound.md)

### Inferences
- **Recommendation for this game:** keep classic Sound and SoundGroups for now. They work, the Settings mute already drives them, and the new API would need rewiring of Audio, Kit and MinigameFx. Revisit if music ducking or audio visualisers become a priority. For that, `AudioAnalyzer` can drive runway lights to the beat.
- **Cheap ducking without the new API:** when a big SFX plays (Podium, results reveal), tween `Music.Volume` down about 40–60% for 1–2 s and back with TweenService on the client.
- **Play UI and feedback sounds on the client.** Server-played sounds replicate to everyone and bypass each client's own mute. The codebase already does this through Kit.playSound and MinigameFx (based on the internal roblox-audio skill guidance).
- **Preloading:** call `ContentProvider:PreloadAsync` on the handful of critical sounds (Click, PhaseChange, runway music) on the client after join, not every sound, because preloading slows joins on mobile. (Internal skill guidance; I fetched no official doc page.)
- **3D sounds:** runway crowd applause and camera flashes can be parented to the audience or runway parts with a modest `RollOffMaxDistance` (about 60–100 studs) so they don't blast the lobby. Keep 2D for UI and music.
- **Mobile:** phone speakers have weak bass below about 200 Hz. Pick SFX with mid-high content (clicks, sparkles, claps), avoid bass-only cues, and keep files short and mono to save memory.

### Gaps
- I couldn't fetch the official `audio/objects` page, so the exact `AudioPlayer` property names (`Asset` vs the deprecated `AssetId`), autoload behaviour and any official migration guidance are unconfirmed here.
- I found no official doc on per-device audio memory limits or a cap on concurrent sounds.

## Game-feel sound design for a fashion/runway/social game

### Takeaway
Use short (30–150 ms), quiet, pleasant UI sounds from one sonic family, with slight pitch randomisation
(about 0.95–1.05). Save the longer, louder sounds for rare big moments (theme reveal, podium). Rising pitch
means confirm or progress and falling pitch means back or cancel. Don't make negative sounds harsh, and
never sonically highlight last place.

### Cited Findings
- Taps and clicks should be about 30–150 ms, notifications up to about 500 ms, and a cue should be identifiable within about 200 ms. — [Violet Recording: How to design UI sounds](https://violetrecording.com/how-to-design-ui-sounds/); [Bugnet: UI sound design for indie games](https://bugnet.io/blog/ui-sound-design-for-indie-games) (search summaries; rules of thumb)
- Pitch randomisation starting around 0.95–1.05 hides repetition. Alternatively, use a few variations. — [itch.io dev post](https://itch.io/post/13747824); [Audiokinetic: UI audio from a UI design perspective pt 2](https://www.audiokinetic.com/en/approaching-ui-audio-ui-design-perspective-2)
- Rising pitch signals confirm or forward, falling signals cancel or back, and a flat, dull tone signals denial. Mix UI sounds quieter than feels natural, because they must be pleasant "at the hundredth repetition". Hover sounds should be near-silent or absent. — [Bugnet: How to make UI sounds satisfying](https://bugnet.io/blog/how-to-make-ui-sounds-satisfying) (search summary)
- Derive the whole UI set from one sonic palette, varying pitch and envelope. Negative feedback shouldn't be harsh. — [Violet Recording](https://violetrecording.com/how-to-design-ui-sounds/); [Audiokinetic](https://www.audiokinetic.com/en/approaching-ui-audio-ui-design-perspective-2) (search summaries)

### Inferences
Mapping to this game's slots. Durations and volumes are suggestions derived from the rules above.

| Event / slot | Sound idea | Length | Relative vol | Notes |
|---|---|---|---|---|
| Click (all buttons, catalog item pick) | soft tick or pop | 30–100 ms | low (0.3–0.4) | pitch random 0.95–1.05; no hover sound |
| Equip/remove item on mannequin | fabric swish or soft pop | 100–250 ms | low | random pitch; distinct from Click |
| PhaseChange (Pairing → Theme → Styling → Runway) | short riser or chime | 0.5–1.5 s | medium | same family for every phase |
| Theme reveal | sparkle plus drum hit | 1–2 s | medium-high | rare, so it can be bigger |
| Countdown last 5 s of styling | soft ticks, the last one higher | 50–100 ms each | low→medium | only the last 5–10 s (the code already notes "beeps got annoying") |
| Runway walk | music plus camera-shutter or flash bursts and light applause | loop | music 0.4–0.5 | shutter `rbxasset://sounds/flashbulb.wav` already exists |
| Reaction (emoji react during runway) | tiny pop or heart blip | <150 ms | low | rate-limit per client so spam doesn't stack |
| Heart / vote cast | warm rising chime | 150–300 ms | low-medium | identical for all votes (no score leaking) |
| Results / Podium | drum roll → crowd cheer and fanfare | 2–4 s | high (duck music) | only top 3 get stingers; no sound for others (brief: no visible last place) |
| Coins / reward | coin sparkle, a quick arpeggio | 200–500 ms | medium | for multiple coins, stagger with pitch rising |
| Purchase success | bright confirm chord | 300–600 ms | medium | distinct from coin |
| Alert / error (invalid look, not enough coins) | soft low "bonk" | 100–200 ms | low | never harsh |
| LobbyMoment (minigame start, rank up) | short fanfare | 1–2 s | medium | |
| Minigame elimination | soft "whoosh down", not a buzzer | 200–400 ms | low-medium | keep it kind; kid audience |
| LobbyMusic | chill pop or lounge loop | loop | 0.25–0.35 | quieter than runway music; lets chatter breathe |
| RunwayMusic | upbeat house or fashion-show beat | 30–120 s loop | 0.4–0.5 | different track per theme if wanted |

- **Fatigue:** only music should loop continuously. Every repeated SFX gets pitch variation. Cap simultaneous instances of the same sound (for example, at most 3 overlapping Reaction pops).
- **Music changes by phase:** lobby track, a quieter styling track (players concentrate), the runway track, then a podium sting. Crossfade over about 1 s with TweenService instead of hard cuts.

### Gaps
- Most sources are blogs and tutorial sites. I found no GDC talk transcript to cite. The numbers are rules of thumb, not standards.
- I found no measured data on loudness targets (LUFS) for Roblox mobile.

## What popular Roblox fashion games do with audio

### Takeaway
I found little reliable information. Reviewers of Dress to Impress describe trendy looping background music
that suits the theme, satisfying item-select UI sounds, and crowd reactions during runway walks. Voting
uses 1–5 stars. I found no developer-authored sources for DTI, Fashion Famous or Royale High audio.

### Cited Findings
- Dress to Impress (DTI): reviewers note background music that shifts with themes, satisfying UI sounds on item selection, crowd reactions during runway walks, and the impression that the music is a looped soundtrack. — [Varsity review](https://varsity.co.uk/fashion/28397); [Flat Hat Magazine](https://www.flathatmagazine.com/blog/t27rjf38tksuqa08iaqymg9n4fwsgy); [SteelSeries guide](https://steelseries.com/blog/how-to-play-dress-to-impress) (search summaries)
- DTI structure: players are moved to the dressing room with 360 s to style, rate outfits 1–5 stars, and voting is described as "stingy". "Style Showdown" is a 10-player elimination mode with three-minute rounds. — [Flat Hat Magazine](https://www.flathatmagazine.com/blog/t27rjf38tksuqa08iaqymg9n4fwsgy); [SteelSeries](https://steelseries.com/blog/how-to-play-dress-to-impress) (search summaries)
- DTI scale: about 9.7 billion visits. — [RoWatcher](https://rowatcher.com/news/dress-to-impress-how-a-teen-developer-s-fashion-game-hit-9-7-billion-visits) (secondary)

### Inferences
- The genre's pattern of a theme-matched runway loop plus crowd and applause plus satisfying select sounds matches the slots this game already has (RunwayMusic, Reaction, Click, Podium).

### Gaps
- No primary or developer sources were found for the audio of DTI, Fashion Famous or Royale High. Claims are reviewer impressions only.

## Accessibility: volume, mute, loud sounds

### Takeaway
Provide separate Music and SFX controls (ideally sliders, not just mute), start at modest defaults, avoid
sudden loud stingers, and never make sound the only signal. Every audio cue should have a visual one.

### Cited Findings
- SoundGroup volume multiplies child Sound volume, so a group fader is a valid single control per bus. — [SoundGroup reference](https://create.roblox.com/docs/reference/engine/classes/SoundGroup) (search summary)
- `AudioCompressor` can control a sound's maximum volume (limiting loud peaks). — [Roblox Docs: Audio](https://create.roblox.com/docs/en-us/audio.md)
- UI sounds should be mixed quieter than feels natural, and negative feedback should not be harsh or cause ear discomfort. — [Bugnet](https://bugnet.io/blog/how-to-make-ui-sounds-satisfying); [Audiokinetic](https://www.audiokinetic.com/en/approaching-ui-audio-ui-design-perspective-2) (search summaries)

### Inferences
- The current Settings has Music/SFX mute switches through SoundGroups (`Audio.luau`). The cheapest upgrade is three-step or slider volumes (0, 25, 50, 75, 100%) saved in ProfileStore or settings data, setting `SoundGroup.Volume`.
- Normalise all uploaded files to similar loudness in Audacity before upload, so no single SFX is much louder than the others. Keep podium and fanfare peaks below the music peak plus a small margin.
- Since this is a kids' platform, avoid screams, sirens, harsh buzzers and jump-scare stingers in minigame eliminations.
- Many mobile players play muted, so every audio cue (phase change, countdown, vote) must also have a visual cue (banner, timer flash).

### Gaps
- I found no official Roblox accessibility guideline document specific to audio in this research pass.
