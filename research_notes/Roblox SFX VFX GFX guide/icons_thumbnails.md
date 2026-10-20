# Roblox Icons, Thumbnails and Video Thumbnails for Discovery (as of October 2026)

Research date: 2026-10-20. Primary sources are Roblox Creator Hub docs (last_updated 2026-10-19/20) and DevForum staff announcements. Where only third-party sources exist, they are labelled.

## Current specs and where to upload (icon, image thumbnails, video thumbnails)

### Takeaway
Icon: one square image per locale, upload at least 512x512 (it shows as small as about 150x150). Thumbnails: 16:9, ideally 1920x1080 and under 3 MB, in .jpg/.gif/.png/.tga/.bmp. A game detail page holds up to 10 images and videos, and 2 to 5 of them can be active on the Home page. Gameplay videos are uploaded directly (3 uploads a month). Since 19 Oct 2026 a game needs at least one custom thumbnail to get any Home recommendation impressions.

### Cited Findings
- Icon: "use a template of 512×512 pixels". Icons scale down to sizes like 150×150 in places, so preview them small. They must be square and "at least 512×512". One icon per locale. A default icon is generated automatically at first publish. — [Roblox Docs: Icons](https://create.roblox.com/docs/production/publishing/experience-icons)
- Icon upload path: Creator Dashboard > game > Configurations > Places > start place (star) > Icon > media type Image > Change > Save Changes. All icons must pass moderation before others see them. — [Roblox Docs: Icons](https://create.roblox.com/docs/production/publishing/experience-icons)
- Thumbnails appear on the Home page and at the top of the game detail page. Up to 10 images or videos per detail page, all moderated against the Community Rules and Terms of Use. Three types exist: uploaded image (free), uploaded video (free, quota of 3 uploads a month), and an auto-generated image taken from Studio's camera at the last publish. — [Roblox Docs: Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails)
- Image spec: 16:9, ideally 1920×1080. Formats: .jpg, .gif, .png, .tga, .bmp. Images that are not 16:9 are stretched to 16:9 when displayed. For personalization uploads, "keep these images under 3 MB and 1920×1080 pixels". — [Roblox Docs: Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails)
- Thumbnail upload path: Creator Dashboard > game > Configurations > Places > a place > Thumbnails. It has a **Home Page** tab and an **Experience Detail Page** tab, and the detail page tab supports reorder, delete and alt text. Videos are uploaded in the same place via the **Videos** item in the left nav. — [Roblox Docs: Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails)
- Video thumbnails: an uploaded "authentic gameplay video" (the docs mention no YouTube link option). Once approved it appears first on the detail page and can also show on Home. Not supported on Xbox, PlayStation or VR headsets. — [Roblox Docs: Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails)
- OUTDATED: Older Roblox systems let you attach YouTube video thumbnails, a feature that required ID verification or Premium. The current doc lists only uploaded video, so treat YouTube-link guides as obsolete. — [Roblox Docs: Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails) (no YouTube option listed). I found no current source that states the change explicitly.
- Search results switched from 1:1 icons to 16:9 thumbnails (DevForum staff announcement, 16 Mar 2026). Search pulls from the game's 16:9 promotional thumbnails. 1:1 icons are still used elsewhere on the platform, and Roblox advises creators to keep optimizing them. — [DevForum: Search results will now show 16:9 thumbnails](https://devforum.roblox.com/t/search-results-will-now-show-169-thumbnails/4525356)
- **NEW (19 Oct 2026):** "only games with a custom thumbnail will receive impressions from homepage recommendations. If your game only has a default thumbnail, it won't be eligible." Upload at least one custom 16:9 thumbnail. You can activate "up to five". Games with only a default thumbnail still appear in players' Continue sort. — [DevForum staff: Homepage Recommendation Eligibility Now Requires a Custom Thumbnail](https://devforum.roblox.com/t/homepage-recommendation-eligibility-now-requires-a-custom-thumbnail/4945086); also stated in [Roblox Docs: Discovery](https://create.roblox.com/docs/discovery) ("Use a custom thumbnail ... required")
- Event thumbnails: an Experience Event can have up to 5 thumbnails. — [Roblox Docs: Discovery](https://create.roblox.com/docs/discovery)
- The icon and thumbnail can also be uploaded at first publish in Studio (File > Publish > Game details window). — [Roblox Docs: Publish games](https://create.roblox.com/docs/production/publishing/publish-games-and-places)

### Inferences
- Detail-page and Home counts are two different limits: up to 10 media items on the detail page, and 2 to 5 "active" thumbnails for Home personalization. The DevForum FAQ's "up to five" refers to the Home Page tab.
- Since Search (from March 2026) and Home both lean on the 16:9 thumbnail, and Home now requires a custom one, the 16:9 thumbnail is at least as important as the icon for a launch. A new game should ship 2 to 5 distinct 1920x1080 thumbnails plus a 512x512 icon. Do not launch on the auto-generated image.
- Keep important art away from the bottom of a thumbnail. Roblox says metadata such as the player count may cover it ([Thumbnails best practices](https://create.roblox.com/docs/production/publishing/thumbnails)).

### Gaps
- No official max file size for icons, and no official video specs (length, resolution, file format, size) appeared in the docs I read. The Videos upload page in Creator Dashboard likely shows them. Check there.
- How video upload eligibility works (whether ID verification is required) isn't stated in the current doc.
- The creatorxp.gg guide claims icons show in sponsored ad placements, notification cards and friends-playing lists. That is a third-party claim I could not confirm with Roblox.

## Moderation and policy rules for icons, thumbnails and videos (2024-2026)

### Takeaway
Every icon, thumbnail and video is moderated against the Community Standards and Terms of Use. Videos have the strictest written rules: real gameplay only, no voice-over or lyrics, no promotional claims. Discovery separately reduces exposure for misleading, giveaway-led or copycat metadata, and the Creator Dashboard shows a banner when exposure is reduced.

### Cited Findings
- All uploaded images and videos are moderated to the [Community Rules](https://en.help.roblox.com/hc/articles/203313410) and [Terms of Use](https://en.help.roblox.com/hc/articles/115004647846). — [Roblox Docs: Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails)
- Allowed in videos: varied camera angles of real gameplay (freecam), minor post-processing (brightness and contrast), a game logo or branding overlay, curated highlight sequences, in-game UI text, and music from Roblox's audio catalog. — [Roblox Docs: Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails)
- Not allowed in videos, and rejected uploads still count against the 3-a-month quota:
  - misrepresented gameplay, or UI and mechanics that aren't in the game
  - "artificial visuals" enhanced beyond what players see
  - real-life footage
  - voice-overs, narration, voice chat or music with lyrics
  - advertising text or subjective claims such as "50% off" or "Free UGC!". Overlay text should be used "sparingly" and only to describe gameplay.
  — [Roblox Docs: Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails)
- Reasons Roblox reduces a game's exposure:
  - "Leading with giveaways": metadata implying monetary rewards, e.g. a title like "Robux! Play now!"
  - "Mismatched metadata and content": e.g. a dinosaur thumbnail on a generic obby
  - "Non-unique games": the same title and visuals as an existing game
  — [Roblox Docs: Discovery](https://create.roblox.com/docs/discovery); [Discovery FAQ](https://create.roblox.com/docs/discovery-faq)
- Thumbnails used with personalization must "all accurately reflect your game". Roblox recommends "original imagery and naming that you or your teammates created". — [Roblox Docs: Discovery](https://create.roblox.com/docs/discovery)
- Consequence and visibility check: games with reduced exposure show a Creator Dashboard banner that "updates daily". Quality is reclassified with each update. Reusing your own old icons and thumbnails "shouldn't negatively affect discoverability". — [Discovery FAQ](https://create.roblox.com/docs/discovery-faq)
- Name and description rules: no keyword repetition or spam (it "may result in demotion"), use "one or two well-placed emojis" at most, and keep the name stable, because renaming often hurts findability. — [Roblox Docs: Publish games](https://create.roblox.com/docs/production/publishing/publish-games-and-places)
- Community commentary (not policy): a Roblox staffer on the DevForum advised avoiding clickbait in ads entirely. One creator reported an account warning over a text-only icon. — [DevForum ad rejection thread](https://devforum.roblox.com/t/what-specific-part-of-my-ad-is-getting-it-rejected/629884); [DevForum warning thread](https://devforum.roblox.com/t/got-a-warning-from-roblox-for-a-ridiculous-reason/3927496)
- Whether AI-generated thumbnails count as "custom" was asked in the Oct 2026 thread and got no staff answer. Community replies assume only the default placeholder is excluded. — [DevForum custom thumbnail thread](https://devforum.roblox.com/t/homepage-recommendation-eligibility-now-requires-a-custom-thumbnail/4945086)

### Inferences
- For still image thumbnails, Roblox's written rules are lighter than for videos. The same principle still applies: no fake UI, no Robux or "free UGC" claims, no imagery the game lacks. Showing a runway, a mannequin and best-friend avatars that really appear in Style My Bestie is safe. A "FREE ROBUX" badge or a fake "1M visits" badge is risky.
- Using another game's icon look, such as Dress to Impress's style, risks the "non-unique" downrank as well as a clone perception.

### Gaps
- I found no official written limit on the amount of text in icons or still thumbnails, and no explicit rule against fake UI in still images.
- I found no official list of strike or ban consequences for rejected icons or thumbnails, beyond general asset moderation.

## Roblox's own testing tools and how the 2026 discovery algorithm uses the icon and thumbnails

### Takeaway
Thumbnail Personalization is Roblox's only native "A/B" tool for store art. It is a multi-armed bandit over 2 to 5 active Home thumbnails, and it reports impressions, qualified plays and play-through rate per thumbnail. There is no native icon A/B test. In June 2026 the Recommended-for-You (RFY) algorithm replaced qPTR with play-through rate (PTR) and first-play bounce rate, so art that wins clicks but disappoints players gets punished.

### Cited Findings
- Personalization was announced on 13 Nov 2024 and launched for everyone on 13 Feb 2025. Early adopters saw an average +8.5% qPTR, and some saw +50%. It works like a multi-arm bandit (faster than a classic A/B test). — [DevForum: [Live now] Personalize your thumbnails](https://devforum.roblox.com/t/live-now-personalize-your-thumbnails-to-attract-more-users/3257233)
- How it works: it starts only when 2 or more thumbnails are active (2 to 5 can be activated). It shows each thumbnail to random users, then gives more impressions to the winner for each user group while keeping some exploration traffic. Setup: Home Page tab > Edit active thumbnails > upload or tick Active > Save > Start. — [Roblox Docs: Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails)
- Metrics: the Thumbnail Performance table fills "after a few hours" and shows Impressions, Qualified Plays, Average Playtime, Qualified Play Through Rate (qualified plays ÷ impressions) and Winning Segment. Graphs show impressions and QPTR per thumbnail. — [Roblox Docs: Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails)
- Advice: keep several thumbnails active rather than picking one winner. Test new thumbnails with each major update, then leave them alone until the next update. — [Roblox Docs: Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails)
- Open Cloud APIs for managing thumbnails and targeting rules programmatically were announced 24 Aug 2026. (Seen in search results only; I did not open the page.) — [DevForum: New OpenCloud APIs ... Thumbnail Personalization](https://devforum.roblox.com/t/new-opencloud-apis-for-analytics-events-experiments-and-thumbnail-personalization/4828676)
- No native icon A/B testing. Icon A/B testing remains an open feature request (filed Nov 2024). Creators rotate icons one after another and compare windows, using the icon-change markers on analytics charts (added 9 Oct 2023). The in-experience Experiments framework does not cover icons. — [creatorxp.gg (third-party, May/Oct 2026)](https://creatorxp.gg/guides/roblox-game-icon-mistakes); [DevForum feature request](https://devforum.roblox.com/t/add-ab-testing-and-stats-for-titles-icons/4778726)
- RFY's most important signals: play through rate, first play bounce rate (a negative signal, measured over <60 s and 61-180 s), play days per user, and playtime per user (capped at 60 min per user per day). Next in importance: intentional co-play days, qualified play sessions, spend days, and Robux spent. All are measured on users who joined organically from RFY. — [Roblox Docs: Discovery](https://create.roblox.com/docs/discovery); [Discovery FAQ](https://create.roblox.com/docs/discovery-faq)
- PTR is "the rate at which users play your game after seeing it in the Recommended for You sort". That makes it the click-through metric the icon, thumbnail and title drive. — [Roblox Docs: Discovery](https://create.roblox.com/docs/discovery)
- qPTR was removed in June 2026 and split into PTR and first-play bounce rate (third-party summary, linking DevForum "Recommended for You algorithm improvements that better value long-term retention"). Note the Thumbnails doc still says "qualified play through rate" for personalization. — [creatorxp.gg](https://creatorxp.gg/guides/roblox-game-icon-mistakes); [Roblox Docs: Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails)
- Signals are per-user averages, not totals, so small games are not disadvantaged. New games get early signals right away (PTR and bounce in the first session, then D1, D2-7, D8-28). There is no lasting penalty for a weak start: the algorithm keeps re-testing daily. — [Discovery FAQ](https://create.roblox.com/docs/discovery-faq)
- Retrieval needs only "a very low minimum number of plays from any source". Friends, social sharing, search and so on can speed up consideration, but ranking uses only RFY-acquired users. Users first acquired via ads never count toward RFY signals. — [Roblox Docs: Discovery](https://create.roblox.com/docs/discovery); [Discovery FAQ](https://create.roblox.com/docs/discovery-faq)
- Home traffic peaks on Saturdays and has summer, back-to-school and holiday seasonality. A temporary PTR drop when impressions rise is normal. — [Roblox Docs: Discovery](https://create.roblox.com/docs/discovery)
- Where to read results: Creator Analytics > Acquisition > Home Recommendations. It shows per-signal charts and benchmarks against similar games. Benchmarks do not affect ranking. — [Roblox Docs: Discovery](https://create.roblox.com/docs/discovery)
- Genre tags are not ranking factors, but inaccurate tags cause bounces. "An accurate gameplay video on your game details page also helps set the right expectations." — [Discovery FAQ](https://create.roblox.com/docs/discovery-faq)

### Inferences
- Zero-budget test plan:
  1. Launch with 3 to 5 thumbnails and personalization on.
  2. Read the table after a few days.
  3. Swap only the losers at each update.
  4. Test the icon one variant at a time, giving each one about a week or more, and log the change dates.
- Because bounce in the first 60 to 180 s is a top negative signal, the art should promise what the first minute delivers: lobby, then pairing, then styling. Showing only the final runway, when the first minute is waiting in a lobby, risks bounces.

### Gaps
- I did not open the June 2026 RFY change announcement itself (rate limits). The qPTR-to-PTR change rests on a third-party summary plus the current Discovery doc, which lists PTR and no longer lists qPTR.
- Roblox publishes no click-through benchmark numbers for icons or thumbnails.

## Design best practices that convert (general and fashion genre)

### Takeaway
Roblox's official guidance is brief: be sharp, square or 16:9, unique, show relevant gameplay, and use colour and contrast that match the theme (bright and saturated for fun or dreamy games). Community guidance adds: make the genre readable at 128 px, show one clear subject doing the core action, and make the icon and title tell the same story. I found no reliable sourced analysis of fashion-genre icons.

### Cited Findings
- Official icon best practices: high resolution and square; unique, relevant imagery; avoid ambiguous graphics and the default icon; use colour and contrast to express the theme ("Bright, high-saturation colors for a fantasy or dreamy setting"). — [Roblox Docs: Icons](https://create.roblox.com/docs/production/publishing/experience-icons)
- Official thumbnail best practices: sharp 16:9; unique, relevant imagery showing what players can expect; theme and colour (an example shows a "comical theme/character with bright colors"); nothing essential at the bottom. — [Roblox Docs: Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails)
- "Add your own spin to existing trends in the title, images, description". — [Roblox Docs: Discovery](https://create.roblox.com/docs/discovery)
- Third-party (creatorxp.gg, 2026) list of icon mistakes:
  - genre invisible at a glance
  - impressive but not specific (show the action, not just the world)
  - detail lost at 128x128 (small text, several faces, thin strokes)
  - icon disagrees with the title
  - icon overpromises the first minute
  - copying a current hit's look
  - changing the icon too early
  - shipping your favourite instead of a tested variant
  Suggested check: show the icon to 5 people who don't know the game and ask "what is this?". — [creatorxp.gg](https://creatorxp.gg/guides/roblox-game-icon-mistakes)
- Third-party (same source) claim: before a player opens the game page, the icon and title carry the decision. Note this predates or ignores the March 2026 change to 16:9 in Search and the Home thumbnail personalization, so it partly conflicts with [DevForum: Search 16:9](https://devforum.roblox.com/t/search-results-will-now-show-169-thumbnails/4525356). — [creatorxp.gg](https://creatorxp.gg/guides/roblox-game-icon-mistakes)
- Dress to Impress's core loop is styling to a runway theme under a timer (325 s per round per Sportskeeda). That is useful context for showing "theme + outfit + runway". — [Sportskeeda DTI guide](https://sportskeeda.com/roblox-news/dress-to-impress-a-definitive-guide)

### Inferences (not sourced; based on general practice, verify against live Home page)
- For Style My Bestie, these follow from the official "show what players do" rule:
  - Icon: two expressive avatars (stylist and "bestie") with a clear reaction such as a shocked or delighted face, a pink or pastel high-saturation palette, and one strong prop (runway, a star rating, or a clothes rack). Use at most 2 to 3 words of title text, or none.
  - Thumbnails: one per phase (secret styling at the booth, runway walk, rating or reveal), each with real in-game UI.
- Keep the icon and thumbnails consistent: the same characters, palette and logo. Seasonal or update badges ("NEW THEMES") are fine as gameplay descriptions. Avoid Robux or "free" claims.

### Gaps
- I could not open or verify the current icons of Dress to Impress, Fashion Famous or similar games (roblox.com pages weren't fetched), so genre patterns are unsourced.
- No Roblox-published data on whether text in icons helps or hurts.

## Free tools and workflows to make the graphics

### Takeaway
Everything needed is free:
- Studio's freecam (Shift+P in a solo playtest) for in-game shots and gameplay video
- Studio "Export Selection" or Save to .obj/.fbx/.glTF to get avatars into Blender (free) for posed renders
- Blender import with Roblox-matching axis and scale settings
- Free 2D editors (Photopea, GIMP, Krita, Canva free) for compositing text

### Cited Findings
- Freecam: Left Shift + P toggles free camera during a solo playtest. Roblox recommends it for "cinematic screenshots and video", and it has a config menu and post-processing options. — [Roblox Docs: Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails); [Roblox Docs: Free camera](https://create.roblox.com/docs/workspace/camera/free-camera)
- Blender is free and open source. Roblox's Blender guide covers unit setup (Unit System None for studs) and importing from Studio as .obj, .fbx or .glTF (File > Import). For orientation, set Forward Axis to Z and Up to Y, and Scale 1. — [Roblox Docs: Blender](https://create.roblox.com/docs/art/blender); orientation per [search summary of the same doc](https://create.roblox.com/docs/en-us/art/blender.md)
- Avatar export from Studio: right-click the avatar model in Explorer, choose Export Selection, and save as .obj/.fbx (third-party). An alternative is the Rig's Save/Export as Obj or glTF (KatsBits). Recentre the model first, because it exports at its position in the world. Some restricted catalog items may block export. — [Homestyler guide](https://www.homestyler.com/article/transform-your-roblox-avatar-into-a-d-model?lang=fr_FR); [KatsBits: Import Roblox avatars into Blender](https://www.katsbits.com/codex/?p=10600)
- Roblox's avatar docs say to use .fbx or .gltf rather than .obj when you need rig or skin data. — [Roblox Docs: avatar export](https://create.roblox.com/docs/avatar/character-bodies/export)
- Video tutorials for Studio-to-Blender avatar renders exist on YouTube, e.g. "How To Render Roblox Characters In Blender" and "How To Create Quality Roblox Thumbnails". — [YouTube kpALOtLhX-Q](https://www.youtube.com/watch?v=kpALOtLhX-Q); [YouTube uS4cB1w_7gI](https://www.youtube.com/watch?v=uS4cB1w_7gI)
- Renderbux: a free web tool (no signup to try) that loads a Roblox avatar by username, poses it in 3D and exports thumbnail-ready PNGs. It is third-party, so check its terms. — [renderbux.com](https://www.renderbux.com/)
- Video music: only tracks from Roblox's audio catalog are allowed. — [Roblox Docs: Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails)

### Inferences
- Divyansh already has the building in Blender (`assets/models/SMB_*.glb`, exported 1 m = 1 stud). The simplest path is to export posed avatars from Studio as .obj or .fbx, import them into that .blend scene, and render with Eevee at 1920x1080 and 512x512 (or 1024x1024 scaled down). Then add the title text in Photopea or GIMP.
- Thumbnails must not look better than the game ("Artificial Visuals" rule for videos, and "accurately reflect" for images). So keep Blender renders close to the in-game look, or use real in-game screenshots for at least some thumbnails.

### Gaps
- I did not research or verify:
  - the licences of specific free fonts (for example, Google Fonts are generally SIL OFL, but confirm per font)
  - Canva free-tier licence terms
  - Studio high-resolution screenshot settings (graphics quality, hiding the CoreGui)
  Check these before relying on them.
- No official Roblox Blender plugin for importing avatars was found in the docs I read. The "Roblox Blender plugin" Roblox publishes is for avatar or asset upload, and I could not confirm what it covers.

## Other store-page items and audience (title, description, genre, maturity, publishing reach)

### Takeaway
The name and description should be accurate, keyword-relevant and free of spam. The maturity questionnaire decides who can see the game. Under the 2026 publishing rules, a game is shown only to age-checked users 16+ unless the owner verifies his account, turns on 2FA, and has 2 months of Premium or Roblox Plus or pays a refundable 1,000 Robux fee. That matters a lot for a fashion game whose audience includes children.

### Cited Findings
- First publish (Studio File > Publish): upload the icon and thumbnail, then set Name, Genre plus optional Subgenre, and Description. — [Roblox Docs: Publish games](https://create.roblox.com/docs/production/publishing/publish-games-and-places)
- Description: summarise the game in the first sentence and include relevant keywords, but don't spam unrelated game names ("may result in demotion"). — [Roblox Docs: Publish games](https://create.roblox.com/docs/production/publishing/publish-games-and-places)
- Release rules (current doc). Answering "No" to age-restricted content gives a "Content May Vary" label and release only to age-checked users 16+. Releasing to all ages, including Roblox Kids and Select accounts, requires all of the following:
  - verification (facial age estimation if under 18, government ID if 18+)
  - 2FA
  - either 2 consecutive months of Roblox Plus or Premium, OR a one-time refundable 1,000 Robux publishing fee (refunded if the game keeps 25 highly engaged players for 60 days) — **PAID / costs Robux**
  - passing the Kids and Select evaluation
  - a complete Maturity & Compliance Questionnaire with a Minimal, Mild or Moderate (9+) rating
  An expedited review costs 50,000 Robux (refundable) — **PAID**. — [Roblox Docs: Publish games](https://create.roblox.com/docs/production/publishing/publish-games-and-places)
- Baseline release requirement: the account must be in good standing, at least 2 days old, and have passed an age check. Up to 5 never-released games can be released per day. Up to 10 early testers can be invited before release. — [Roblox Docs: Publish games](https://create.roblox.com/docs/production/publishing/publish-games-and-places)
- Maturity questionnaire location: Creator Dashboard > Audience > Maturity & Compliance. Roblox uses it to recommend games on Home and Charts by age group and region. Building outfits from 3D assets is NOT "free-form user creation" (which would make the game 13+). Social hangouts are 13+. Romantic themes are 17+. — [Roblox Docs: Experience guidelines](https://create.roblox.com/docs/production/promotion/experience-guidelines). Note: this page uses the older "Experience guidelines / 13+ default" wording, which conflicts with the newer "Content May Vary, 16+" flow in [Publish games](https://create.roblox.com/docs/production/publishing/publish-games-and-places). Trust the newer publish doc for release rules.
- Option to exclude a game from RFY: Audience > Advanced Settings. — [Roblox Docs: Publish games](https://create.roblox.com/docs/production/publishing/publish-games-and-places)
- Sponsored ads (Ads Manager) are **PAID**. Ad-acquired users don't count toward RFY, and running ads doesn't penalise RFY. — [Discovery FAQ](https://create.roblox.com/docs/discovery-faq)
- Search now supports semantic natural-language queries (e.g. "avatar editors"), so an accurate description and title help. — [Roblox Docs: Discovery](https://create.roblox.com/docs/discovery)

### Inferences
- For Style My Bestie: don't add romance framing ("bestie", not "date"), since romantic themes trigger 17+. Outfit-building is not free-form creation. With no free text, the game should be able to get a Minimal or Mild rating if the questionnaire is answered fully.
- At ₹0 budget, reaching under-16 players requires ID or face verification plus 2FA and either Premium for 2 months or 1,000 Robux, which is refundable after 60 days with 25 engaged players. This is a launch blocker to flag in LAUNCH_CHECKLIST.

### Gaps
- Title and description character limits were not found in the docs I read.
- Social link rules ([Social media links doc](https://create.roblox.com/docs/production/promotion/social-media-links)) were not opened.
- Badge and pass icon sizes were not researched in this pass.
