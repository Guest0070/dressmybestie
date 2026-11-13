# PLAN

Phase 3. Order: launch blockers, then high impact for low effort, then later. Source of each item:
AUDIT.md (B/S/P/D/C numbers) and REDESIGN.md. Status as of 13 Nov 2026.

Nothing in this plan has been run in Roblox. "Done" means written, type-checked and built.
**Every done item still needs the Studio test listed in CHANGELOG.md.**

## 1. Launch blockers

| # | Item | Who | Status |
|---|---|---|---|
| 1 | Full playtest: solo, 2 players, 3 players, phone. Use the test list in CHANGELOG.md. | Divyansh + Rishabh | **To do** |
| 2 | Create the last 2 badges (`Rank5`, `Wardrobe`), paste IDs into `Config.Badges` (B2) | Divyansh / PC session | **To do** |
| 3 | Studio settings: R15, API access, Third Party Sales; Lighting Realistic; check Workspace > StreamingEnabled and tell me its value (B3) | Divyansh | **To do** |
| 4 | Catalog lookup flood (S1) | code | Done |
| 5 | Save format version + migration hook (D1) | code | Done |
| 6 | Ask Roblox to load the destination before teleports (B3) | code | Done, needs phone test |
| 7 | Store page: rename to "Style My Bestie", icon, 3 thumbnails, description, questionnaire (REDESIGN §8) | Divyansh | **To do** |
| 8 | File > Save to Roblox, set Public | Divyansh | **To do** |

## 2. High impact, low effort

| # | Item | Status |
|---|---|---|
| 9 | Styling 240 s → 120 s; "half are READY → 20 s left" rule | Done |
| 10 | Lobby countdown 30 s → 20 s | Done |
| 11 | Chaos rounds about every other round, never round 1 | Done |
| 12 | New chaos round: Speed Round (45 s) | Done |
| 13 | 15 extra-silly themes (70 total) | Done |
| 14 | 150 welcome coins; 25 coins per round (was 10) | Done |
| 15 | Audience earns 2 coins per look rated | Done |
| 16 | Bestie bonus 10% → 25% | Done |
| 17 | Podium ranking uses a smoothed average (S3) | Done |
| 18 | Coin caps and cooldowns saved per player (B7) | Done |
| 19 | Stars hidden by user ID, not display name (B4) | Done |
| 20 | Booth panels found by tag, not by watching the whole world (P1) | Done |
| 21 | One data sync per player per frame (P5) | Done |
| 22 | All-time board saved when a player leaves (B6) | Done |
| 23 | How-to-play card cut to four short lines; first-round hint in the booth | Done |
| 24 | Wardrobe delete and Shop TRY buttons enlarged | Done |
| 25 | Settings saved through the normal data path (D2); duplicate boot prints (B9); unused config (B10) | Done |

## 3. Next, after the first playtest (each needs to be seen in Studio)

| # | Item | Effort | Why it waits |
|---|---|---|---|
| 26 | POSE button for the walker on the runway | M | New input + animation; must be felt, not guessed. |
| 27 | "Invite a friend" prompt while waiting for players (1/2) | S | Wants a look at where it sits on a phone. |
| 28 | Blindfold chaos round (catalog pictures hidden) | M | Catalog UI change. |
| 29 | Tune the numbers from items 9–17 using real sessions | S | Needs data. |
| 30 | Minimum time / path checks on Runway Dash and gems (S2) | M | Low coin value now that caps are saved. |

## 4. Later (tidy-up; no player sees it)

**I am not doing these now, on purpose.** Each is a large edit to code that has never been
playtested in its current form. Doing them before a playtest would add risk and help no player.

| # | Item | Effort |
|---|---|---|
| 31 | Remove Hearts voting mode (B5) | M |
| 32 | Split `RoundManager` (C1) and `Config` (C2) | L |
| 33 | One UI toolkit (C3), one colour table (C4), shared builders (C5) | L |
| 34 | One `Leaderboards` module for the two ordered stores (D3) | M |
| 35 | Remove the code-built placeholder world once the building is saved in the place (C6) | L |
| 36 | Controller / console support | L |
| 37 | Volume sliders | M |

## Questions for you (batched)

1. **StreamingEnabled:** in Studio, click Workspace and tell me whether StreamingEnabled is ticked.
2. **Arcade hall and stage looks:** were `SMB_ArcadeHall.glb` and the stage looks imported and saved?
3. **Group or personal:** is the game owned by your account or by a group? (Decides who is admin.)
4. **Hearts mode:** OK to delete it for good (item 31)?
5. **Button size:** you asked for small lobby buttons. If you or Rishabh miss taps on a phone, say so and I'll raise the floor from 36 to 44 px.
6. **Max players:** I suggest 10 per server. OK?
