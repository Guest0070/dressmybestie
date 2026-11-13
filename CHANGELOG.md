# CHANGELOG

Newest first. Each entry: what changed, why, and how to test it in Studio.

## 13 Nov 2026 — build `2026-11-13a`

Check first: press Play, Output must show `[StyleMyBestie] Server started - BUILD 2026-11-13a`.
None of this has been run in Roblox; it is type-checked and builds.

### Pacing
- **Styling is 2 minutes (was 4).** `Config.Timings.Styling = 120`.
- **Hurry rule.** After 45 s, once half the stylists have tapped READY, everyone else gets 20 s.
  Why: one slow player was holding the whole server.
  *Test (2 players):* both in a booth, wait 45 s, one taps READY. The other should see
  "Hurry! 20 seconds left" and the timer jump to 0:20.
- **Lobby countdown is 20 s (was 30).**

### Funny
- **Chaos rounds about every other round** (even rounds, 70%), never round 1. Was every 4th at 60%.
- **New chaos round: Speed Round**, 45 seconds to style.
  *Test:* Admin panel > "Chaos: Speed Round", then Start now; the styling timer starts at 0:45.
- **15 new themes** (70 total), e.g. "Lost a Bet", "Undercover as a Lamp".

### Economy
- **New players start with 150 coins.** Existing saves are not changed.
  *Test:* Admin panel > Reset my data. Coins should read 150.
- **25 coins for playing a round (was 10).**
- **Audience pay:** 2 coins per look you rate. *Test (2 players):* rate the other look; at results
  you get a "+2 coins for rating 1 look!" message.
- **Bestie bonus:** playing a round with a Roblox friend gives +25% round coins (was 10%).
- **Fairer podium.** Ranking uses a smoothed average so one 5-star vote can't beat a look many
  people rated highly. The number shown is still the real average.
- **Coin caps are saved.** Gems: 120 coins a day. Minigame wins: 300 coins a day (was 6 wins an
  hour). Obby and Runway Dash rewards: once per 10 minutes. Rejoining no longer resets them.
  *Test:* collect a gem, Stop, Play again; the gem count toward the cap carries on. (Admin >
  Reset my data clears it.)

### Security
- **Catalog lookup flood closed.** Failed item lookups are remembered for 30 s and each player may
  cause at most 40 new lookups per 10 s. Normal play is far below that.
  *Test:* style normally with fast taps across several tabs; every item should still appear.
- **Stars are hidden by user ID**, not display name (two players with the same name both rate).

### Saving
- **Save version number** (`Config.Data.Version = 1`) and a migration list in `PlayerData.luau`.
  Old saves are treated as version 1. No data is changed.
- **Settings are saved through the normal data path.**
- **All-time leaderboard is saved when you leave** (it used to be skipped).

### Performance
- **Booth panels** find their zones by tag. Before, the client inspected every object ever added
  to the world. *Test:* walk into the Skin Tone and Body Type booths; the panels still open.
- **One data sync per player per frame**, not one per change.
- **Teleports ask Roblox to load the destination** (booth, runway). *Test on a phone emulator:*
  when styling starts the booth should be there, not an empty void.

### Onboarding and touch
- **How to play** is four short lines with emoji.
- **First-round hint** over the booth: "👆 Tap clothes to dress NAME, then tap READY!" until the
  first item is on. *Test:* Reset my data, start a round.
- **Bigger buttons:** Wardrobe delete (36×36), Shop TRY (56×36).

### Tidy
- Removed two unused config values and the duplicate "started" lines in Output (the last line is
  now "Server ready" / "Client ready").

### Docs
- Added AUDIT.md, REDESIGN.md, PLAN.md and this file.

## 12 Nov 2026 and earlier
See `git log`. Summary of the 12 Nov pass: Flashing-effects switch fix, shop card layout and emoji
previews, Hall of Fame statues on the building's podium, queued booth changes, frame-rate
independent cameras, group-owner admin.
