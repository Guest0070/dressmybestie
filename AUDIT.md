# AUDIT: Style My Bestie as it stands (13 Nov 2026)

Phase 1 of the takeover. Nothing in the game was changed to write this.

**How it was checked.** Read from source: all of `src/shared`, the server's data, money, round,
voting, styling, quests, cosmetics, lobby and admin modules, and the client's state, both UI
toolkits and every screen. Skimmed (searched for loops, connections, rewards, remotes, but not read
line by line): the five minigame modules, `MapDecor`, `BlendImport`, `MinigameUI`, `MinigameFx`,
`AdminPanel`, `Auras`, the Python asset tools. Not read: the two generated data files
(`BlendData`, `BlendPieces`). Automated checks run: format, type check (0 errors), `rojo build`,
the pairing test, 19 Python pipeline tests. **Nothing was run in Roblox**, so anything about feel,
frame rate or how screens look is a reading of the code, not a measurement.

Severity: **[BLOCKER]** fix before launch · **[HIGH]** hurts players or money soon after ·
**[MED]** worth fixing · **[LOW]** tidy-up.

---

## 1. How the game works today

**Join.** ProfileStore loads the player's save (kicks them if it can't). They spawn in the lobby:
the imported Blender building if it was set up, otherwise a code-built placeholder plaza. A
"How to play" card opens for anyone with 0 rounds played. The Welcome badge is awarded.

**Lobby.** Top bar shows coins, level/XP, and the round status. Buttons: Join/Spectate, Customize
(Dressing Room), Shop, Quests, Daily, Games, Invite, How to play. Things to do while waiting: five
minigames (Color Rush, Freeze Frame, Spin Sweep, Cover Star, Runway Dash), a sky obby, gems to
collect, a dance floor, bounce pads, skin-tone and body-type booths, a wardrobe with saved outfits,
Hall of Fame statues of the last winners, two leaderboards.

**Round loop** (`server/Round/RoundManager.luau`), needs 2 players (1 in Studio):

| Phase | Length | What happens |
|---|---|---|
| Lobby | 30 s countdown | Waits for enough non-spectating players. |
| Pairing | 3 s | Everyone is secretly given someone to style. Friends are paired apart when possible. Odd counts make a trio. |
| Theme reveal | 5 s | One of 55 themes (4 VIP-only). Every 4th round has a 60% chance of a chaos twist: Worst Outfit Wins, Swap Mid-Round, One Color Only. |
| Styling | up to 240 s, at least 20 s | You are teleported to a private booth and dress a mannequin of your partner from the live Roblox catalog (9 tabs). Ends early when every stylist taps READY. |
| Runway | 9 s per player | Each player walks wearing what their stylist picked. The audience rates 1–5 stars and taps emoji reactions. |
| (Voting) | 30 s | Only in "Hearts" mode. The game is set to "Stars", so this phase never runs. |
| Results | 15 s | Top 3 by average stars go on the podium. Nobody is shown as last. "Buy this look" opens Roblox purchase prompts for the items. |

Total for 8 players: about 30 + 8 + (20 to 240) + 72 + 15 = **2.5 to 6 minutes**, almost all of it
decided by how fast people tap READY.

**Rewards.** 10 coins + 20 XP for playing. The stylist (not the wearer) gets 1 coin + 2 XP per star
their look received, and 30/20/10 coins for the podium. Bonuses: 2x Coins pass, Premium +10%,
friend in the round +10%, weekend event x2. Typical round: roughly 30–60 coins.

**Spending.** Coins buy entrances, trails, titles, 2 walks and 1 pose (150–1200 coins). Robux buys
4 passes (99–399), 4 coin packs (49–449), 5 server-wide "moments" (49–99), 3 entrances, 8 walks,
3 poses, 6 auras (49–199), and tips (25/100). Everything is a fixed, disclosed item. Nothing random.

**Retention hooks that exist.** 7-day login streak (50→200 coins), 6 daily quests, 17 achievements,
10 ranks with cosmetic unlocks at ranks 3–9, weekly featured theme, weekend double coins, 5 badges.

**Leaving.** Mid-round leavers are removed cleanly: their mannequin goes, their stylist is told and
still gets round rewards. ProfileStore ends the session and saves.

---

## 2. Bugs, broken flows, dead code, half-finished features

| # | Sev | Where | What |
|---|---|---|---|
| B1 | BLOCKER | whole game | **Never playtested end to end since the last ~10 rounds of changes.** Several fixes from 12 Nov (Hall of Fame podium placement, shop card layout, camera easing) have only been type-checked. |
| B2 | BLOCKER | `Config.Badges` | `Rank5` and `Wardrobe` badge IDs are still 0. They are silently never awarded. |
| B3 | HIGH | `Map.luau:22` (booths at x = 600), runway | **No streaming handling.** New Roblox places have StreamingEnabled on. Players are teleported 600 studs to booths and to the runway with no `RequestStreamAroundAsync`. On phones they may arrive before the room has loaded. Needs a Studio check of the place's streaming setting; cannot be verified from here. |
| B4 | HIGH | `StarsUI.luau` `canRate` | Hides the stars from a player whose **display name** matches a stylist's. Two players with the same display name: one loses the ability to rate. The server check is correct (by player); only the client is wrong. |
| B5 | MED | `VotingUI.luau`, `Voting.luau` hearts half, `HUD` voting text, `Config.Timings.Voting`, `Rewards.CoinsPerHeartReceived` | **Hearts mode is dead at runtime** while `VotingMode = "Stars"`, but the screen is still built for every player and all text is written twice. Either a real second mode or ~300 lines to remove. |
| B6 | MED | `Activities.luau` `saveXp` on leave | Runs after ProfileStore has already ended the session, so `PlayerData.get` returns nil and **the all-time board is never saved on leave**, only by the 3-minute loop. A player who leaves inside 3 minutes of a rank-up is not on the board. |
| B7 | MED | `Activities.luau`, `Minigames/Arena.luau`, `RunwayDash.luau` | **Coin caps live only in memory** (gems 120 per visit, obby 1 per 10 min, minigame 6 wins per hour, dash 1 per 10 min). Rejoining resets all of them. |
| B8 | MED | `Activities.luau`, `HallOfFame.luau` (plaza path), `Minigames` | Plaza activities sit at **hard-coded world coordinates**. They only line up with the imported building at its exact offset. Any move of the building in Studio leaves the obby, gems, boards and booths floating in the wrong place. |
| B9 | MED | `init.server.luau` | Prints two different "Server started" lines; the client does the same. Harmless, confusing in Output. |
| B10 | LOW | `Config.Rewards.DailyRewardCoins`, `Config.Limits.MaxEmotes` | Unused config values (the streak table replaced the first; the second is never read). |
| B11 | LOW | `Environment.luau` | Comment promises a "blinking" aircraft light; the part never blinks. |
| B12 | LOW | `Catalog.luau` | "More" button sits inside the item grid, so it is drawn as a square item cell. At the 24-item limit, extra taps do nothing with no message. |
| B13 | LOW | `DressingRoom.luau` | `DeleteOutfit` accepts any number as a slot (harmless: it clears a key that does not exist). |

**Half-finished features**
- **Settings** has on/off switches only. No volume sliders.
- **Console / gamepad:** only the Settings window sets a selected button. No other screen can be
  driven by a controller. The game is effectively touch + mouse only.
- **Arcade hall:** games run there only if `SMB_ArcadeHall.glb` was imported in Studio. Unknown
  whether that was done.
- **Stage looks:** needs `ServerStorage.SMB_StageLooks`. Silently does nothing without it.
- **Fresh clone here has no ProfileStore.** `ServerPackages/` is git-ignored and in this container
  holds only a 1-line stub (the `_Index` folder is missing), so a place built here would not boot.
  On Divyansh's PC it is presumably complete; a new machine must run `wally install`.

---

## 3. Security: what the client is trusted with

**Good news first.** Every one of the 20 client→server events has a server handler that checks
types and ranges, and no handler takes a coin amount, price, item ownership or score from the
client. Checked individually:

| Remote | Validation | Rate limit | Verdict |
|---|---|---|---|
| `SetMannequinLook`, `SetOwnLook` | Full: `LookValidator` re-checks every ID's real asset type against `Config.AssetRules`, slot caps, 24-ID cap | Merged to one per 0.4 s per target | See S1 |
| `RateLook` | type, integer 1–5, look is ratable, not your own / not one you styled | none (state-replace, cheap) | OK |
| `CastHearts` | table, ≤3, candidates only, no duplicates | none (state-replace) | OK (unused) |
| `React` | index in list, runway is on, not the walker | 3 per second | OK |
| `BuyWithCoins`, `EquipCosmetic` | id is string, price from Config, ownership re-checked, spend + grant in one change | 0.25 s (own throttle) | OK |
| `ClaimDailyReward`, `ClaimQuest` | day / progress re-checked inside the data change | 1 s / 0.5 s | OK |
| `SaveOutfit`, `WearOutfit`, `DeleteOutfit`, `ResetOwnLook` | saves the look the *server* applied, never one from the client | 0.5–1 s | OK |
| `SetSkinTone`, `SetBodyType` | index / id must exist in Config | 0.5 s | OK |
| `SetSpectating`, `StylingReady` | boolean only | none | OK |
| `MinigameGo` | known game id, player eligible | 0.5 s + 1 s | OK |
| `SaveSettings` | only three boolean keys kept | 0.5 s | OK |
| `AdminCommand` | permission re-checked on the server every call | 0.25 s | OK |
| `GetMyData`, `GetRoundState` (functions) | read-only | none | OK |

`ProcessReceipt` is idempotent: the purchase ID is written in the same change as the grant, and
`PurchaseGranted` is returned only after a confirmed save.

**Problems**

| # | Sev | What |
|---|---|---|
| S1 | HIGH | **Catalog lookup flood.** `AssetInfo.getAssetType` does not remember failed lookups. A hacked client can send 24 made-up IDs every 0.4 s forever; each one is a `GetProductInfoAsync` web call (up to ~60 a second per attacker). That can use up the server's request budget, and then **nobody's** clothing choices validate: items stop appearing for the whole server. Fix: remember failures for a short time and cap new lookups per player per minute. |
| S2 | MED | **Movement is client-owned** (normal for Roblox), and every lobby coin source is "be at this position": gems, obby finish, minigame survival, Runway Dash time. A teleporting exploiter collects all of them. The obby has a minimum time (8 s); Dash and gems have nothing comparable. Value is small per visit but combines with B7 (rejoin resets caps). Coins are also sold for Robux, so a farm undercuts sales. |
| S3 | MED | **Rating can be skewed by alt accounts.** Any player in the server may rate, including spectators who joined mid-round. No minimum number of ratings before a look can take the podium: one 5-star vote beats ten 4.9s. |
| S4 | LOW | `SetSpectating` has no rate limit and sets a replicated attribute; spam is cheap but not free. |
| S5 | LOW | `Shop.luau` keeps its own throttle instead of using `RateLimit`. Two mechanisms for one job. |
| S6 | LOW | During Styling/Runway the server sets WalkSpeed 0, but the client owns its character, so an exploiter can still walk about. Nothing is gained by it. |

No remote lets a client set currency, inventory, votes for others, or timers. Timers are all
server-side (`endsAt` is display only).

---

## 4. Performance risks

Not measured. These are the places to look first when profiling on a phone.

| # | Sev | Where | Risk |
|---|---|---|---|
| P1 | HIGH | `BoothsUI.luau` `start` | Scans every instance in Workspace at start and then listens to **`Workspace.DescendantAdded` forever**. That fires for every part, particle, attachment and character piece created in the whole game (thousands per round) to find two booth zones. Should use a CollectionService tag. |
| P2 | MED | imported building + `Environment.luau` | Part and mesh count is unknown from here. The building is ~1,000 mesh pieces by the data file; Environment adds 80 towers with up to 12 neon bands each (several hundred parts, shadows off), street lamps with SpotLights. Needs a real device check in Studio (Test > Device, MicroProfiler). |
| P3 | MED | `Audio.luau` runway beat | Creates and destroys a new `Sound` instance for every drum hit, about 8 a second, for the whole runway. Only when no runway track is set; a track **is** set now, so this path is currently idle. |
| P4 | MED | `Cosmetics.luau` | Runs for every data change of every player (each coin, each quest bump): rebuilds leaderstats, re-checks trail and aura. Name tag rebuild was fixed on 12 Nov; the rest still runs each time. |
| P5 | MED | `PlayerData.update` | Every change sends the **entire** public data table (all quests, all cosmetics, outfits) to the client. A round end triggers 5–8 of these per player back to back. Should be coalesced to one per frame. |
| P6 | LOW | `Lobby.luau` | Spins gems and checks bounce pads every rendered frame via `CollectionService:GetTagged` (allocates a new list each frame). |
| P7 | LOW | `LobbyUI`, `HUD`, `MinigameUI`, `Stage`, `MinigameFx`, `Moments` | Six always-on per-frame connections on the client. Each is light and throttled, but none is ever disconnected, including while its screen is hidden. |
| P8 | LOW | `Signal.luau` | `Fire` copies the listener list and spawns a thread per listener on every fire. Fine at this scale. |

**Memory.** No leak across rounds found on the server: `participants`, `assignments`,
`pendingLooks`, mannequins and voting tables are all cleared in `cleanup`, which runs even after a
crash. Per-player tables are cleared on `PlayerRemoving` in every module checked. Small exceptions:
`RoundManager.readyStylists` keeps a leaver until the next styling phase; `Permissions` and
`Activities.names` caches grow by one small entry per visitor for the server's life.

---

## 5. DataStore safety

| Area | State |
|---|---|
| Session locking | Yes: ProfileStore. A second server kicks the player rather than overwrite. |
| Retries | ProfileStore's own. `ProcessReceipt` returns "not processed yet" until a save is confirmed, so Roblox retries. |
| Save on shutdown | ProfileStore's built-in close handling. The game has no extra `BindToClose`, and does not need one for profiles. |
| Load failure | Player is kicked with a message rather than playing unsaved. Correct. |
| New fields | `Reconcile()` fills them from the template. |

**Problems**

| # | Sev | What |
|---|---|---|
| D1 | HIGH | **No schema version.** `Reconcile` only adds missing keys. Any future rename, type change or re-balance of a saved field has no migration path. Add `version` to the template now, before real players have saves. |
| D2 | MED | `SaveSettings` writes into the profile directly instead of through `PlayerData.update` (the one place the project rules say all changes go). Works, but skips the client sync. |
| D3 | MED | **Two OrderedDataStores are called directly** (`StyleXP_v1` in `Activities`, `RunwayDashBest_v1` in `RunwayDash`), against the project rule "never call DataStore directly". Leaderboards cannot go through ProfileStore, so this is a legitimate exception, but it has no retry, no request budgeting, and (B6) the leave-time save never works. It should be one small `Leaderboards` module. |
| D4 | LOW | `processedPurchases` remembers the last 100 receipt IDs. Enough in practice; Roblox retries within days. |
| D5 | LOW | Unbounded growth: none found. `savedOutfits` is capped by slots; quest tables reset daily. |

---

## 6. Code style, duplication, structure

The code is consistent in the small (every file `--!strict`, formatted, 0 type errors, comments
explain why). The problems are structural.

| # | Sev | What |
|---|---|---|
| C1 | HIGH | **`RoundManager.luau` is 1,200 lines and owns too much**: phase timing, pairing set-up, mannequins, look queue, runway walking, animation swapping, name tags, podium placement, AFK tracking, admin controls. Hard to change one part safely. |
| C2 | MED | **`Config.luau` is 1,290 lines** mixing tunables, content lists (55 themes, 60 cosmetics, quests), product IDs and helper functions. One typo breaks boot for everything. |
| C3 | MED | **Two UI toolkits.** `Kit` (design-unit canvas with one UIScale) builds HUD, Catalog, Voting, Results, Quests, Booths, HowToPlay, Stars. `Components` (scale + constraints) builds Lobby, Shop, Settings, Wardrobe, Reactions, Minigame. They share colours but size things differently, so the same button is a different physical size on the same phone depending on the screen. |
| C4 | MED | **Three colour palettes**: `Theme.Colors`, `Config.Vfx.Colors`, `Arena.Colors` (plus literals in `Activities`, `Environment`, `HallOfFame`, `Effects`). Gold is defined four times with three different values. |
| C5 | MED | Repeated helpers: `part()` builder in 4 modules (and variants in 3 more), `getHumanoid` in 4, the gold/silver/bronze place colours in 4, number formatting in 2, "billboard with one text label" built by hand in 6 places. |
| C6 | MED | **World-building code is mixed with game logic.** `Activities`, `Appearance`, `HallOfFame`, the minigames and `Environment` each both *build parts* and *run rules*. Divyansh cannot restyle any of it in Studio; it is rebuilt from code at every server start. |
| C7 | LOW | No automated check runs on push. The only unit test covers pairing. `selene` cannot run in this environment. |
| C8 | LOW | 29 MB of binary assets in git (`assets/`), plus generated Luau data (3,900 lines) committed next to source. |
| C9 | LOW | `CLAUDE.md` has two overlapping architecture sections ("Architecture" and "Architecture details") with slightly different wording for the same facts. |

---

## 7. Where the earlier versions conflict or overlap

I cannot tell from the repository which model wrote which file; the history does not say. What can
be seen is where two approaches were layered instead of one replacing the other:

1. **Hearts voting (the original brief) vs Stars voting (added later).** Both are fully built. Only
   Stars runs. Text, quests and rewards carry `if VotingMode == "Stars"` branches in 9 places.
2. **`Kit` vs `Components`** UI toolkits (C3). The newer one was applied to some screens only.
3. **Code-built placeholder world vs the imported Blender building.** `Map`, `MapDecor`,
   `Activities`, `HallOfFame`, `Appearance` and every minigame carry two code paths chosen at
   runtime (`ImportedMap` attribute, `arcadeImported()`, podium lookup). The placeholder path is now
   only a fallback but is about a third of the lobby code.
4. **Plaza Play Zone vs arcade hall** for the same three minigames: built twice, positioned twice.
5. **Hall of Fame**: a plaza stage (old) and the building's Winners Podium (added 12 Nov).
6. **Sound**: built-in `rbxasset` sounds, then an uploaded-sound pipeline, then a procedural runway
   beat, then licensed music tracks. All four generations are still in `Audio.luau` / `Config.Sounds`.
7. **Rate limiting**: `RateLimit` module (new) next to `Shop`'s own throttle, `Reactions`' own
   window counter and `Minigames`' own `lastGo` timer (old).
8. **Docs**: `README.md`, `LAUNCH_CHECKLIST.md`, `CLAUDE.md` and four reports describe the same
   systems with different levels of staleness.

---

## 8. Design and mobile notes for Phase 2

Recorded here because they came out of reading the code. Decisions belong in REDESIGN.md.

- **A player who joins mid-round waits up to ~5.5 minutes** before they can play the actual game.
  They get minigames, not fashion.
- **First-minute flow is text.** The "How to play" card is four paragraphs. The theme card is up
  for 5 seconds. Nothing shows the player *what to tap first* in the catalog.
- **Styling is capped at 4 minutes** and ends only when *everyone* taps READY. One slow or absent
  stylist holds the whole server (AFK kick takes 2 full rounds).
- **Runway is 9 s per player with nothing for the walker to do** except walk. No pose button, no
  input.
- **The funniest content is rare.** Chaos rounds are every 4th round × 60%: about once every
  25–40 minutes of play.
- **Rewards are small next to prices.** ~30–60 coins a round against 150–1200 coin items: 3 to 30
  rounds for one cosmetic. First purchase is at least 15 minutes away for a new player.
- **Tap targets.** `Theme.MinTouch` is 36 px, below the 44 pt guideline. Lobby side buttons are
  sized as 15% of a 46%-height column and fall to that 36 px floor on a small phone. Wardrobe
  delete is 26×36 px. Shop "TRY" is 52×28 px.
- **Text floor.** `Kit` labels may shrink to 10 px. Shop description minimum was raised to 10 px on
  12 Nov; the catalog has no item names at all.
- **Controller play is not supported** (see half-finished features).
- **Store name.** The experience is still called "Dress My Bestie" on the dashboard.

---

## 9. Could not verify from here

- Anything visual: lighting, how the building looks, whether UI overlaps on a real phone.
- Frame rate and memory on a device.
- Whether the place has StreamingEnabled, R15, API access and Third Party Sales set.
- Whether the arcade hall and stage looks were imported, and whether the place was saved after.
- Whether the 35 product/pass IDs in Config match what is live on the dashboard at the listed prices.
- Whether the uploaded sounds and textures passed moderation.
