# Style My Bestie

A round-based Roblox fashion game. Players pair up, style each other's mannequin without the partner seeing it, walk the runway, then vote with hearts.

## What's built

| System | Files | What it does |
|---|---|---|
| Config | `src/shared/Config.luau` | Every number and every list: timings, limits, rewards, ranks, 35 themes, weekly featured theme, chaos modifiers, shop items, pass/product IDs |
| Remotes | `src/shared/Remotes.luau` | All RemoteEvents/Functions, created by the server. A typo in a remote name errors loudly |
| Data | `src/server/Data/PlayerData.luau` | ProfileStore wrapper (session-locked): coins, XP, rank, unlocks, daily reward, purchase history |
| Round | `src/server/Round/RoundManager.luau` | Lobby → Pairing → Theme → Styling → Runway → Voting → Results. Handles players leaving or respawning at any point |
| Pairing | `src/server/Round/Pairing.luau` | Pairs, trio for an odd count, friends paired together, swap logic for the chaos round |
| Map | `src/server/Round/Map.luau` | Finds the map spots (or builds placeholders), plus private booths |
| Styling | `src/server/Styling/*` | Checks every catalog ID on the server (cached), builds HumanoidDescriptions, restores outfits |
| Voting | `src/server/Voting/Voting.luau` | Hearts only, up to 3, no voting for yourself or your own styling, never reveals who voted |
| Rewards | `src/server/Round/Rewards.luau` | Fixed coins and XP; hearts credit the stylist, podium bonus |
| Shop | `src/server/Monetization/*` | Game passes (cached), idempotent ProcessReceipt, coin shop, equip, lobby moments |
| Analytics | `src/server/Analytics.luau` | Funnel: joined → 1st round started → 1st finished → 2nd finished; purchase + coin events |
| Client UI | `src/client/UI/*` | HUD, catalog browser, voting cards, results podium + "Buy this look", shop. Mobile-first |
| Client stage | `src/client/Stage.luau`, `Moments.luau` | Booth/runway cameras, movement lock, pose at end of walk, confetti/disco |

The server makes every decision. Clients only send requests, and the server checks each one.

## One-time setup (Windows)

1. **Install Rokit:** follow https://github.com/rojo-rbx/rokit#installation, then reopen PowerShell.
2. In the project folder, run `rokit install`. This installs rojo, wally, selene and stylua.
3. `wally install` downloads ProfileStore into `ServerPackages/`. **Run this before `rojo serve`**, or Rojo errors because the folder is missing.
4. `rojo plugin install`, then restart Studio.

## Create the game in Studio (one time)

1. Studio → **New** → **Baseplate**.
2. **File → Publish to Roblox As…** → *Create new game* → name it "Style My Bestie" → **Create**.
3. **Home → Game Settings**:
   - **Avatar** → Avatar Type **R15** → Save.
   - **Security** → turn ON **Enable Studio Access to API Services** (saving data in Studio).
   - **Security** → turn ON **Allow Third Party Sales**. Without it, "Buy this look" can't sell catalog items made by other creators, and those sales are where the 40% commission comes from.
   - Save.
4. **File → Save to Roblox**.

## Every session

1. `rojo serve` in the project folder.
2. Studio → **Plugins → Rojo → Connect**.

## How to test (Studio)

**Solo, the fastest check.** Click **Play** (F5). In Studio a round starts with just 1 player, and you style your own mannequin.
1. Wait out the 30s lobby (the timer is at the top).
2. The theme card appears, then you're put in a pink booth. The catalog is on the right. Tap tabs and items and watch the mannequin change. Try **Undo**, **Clear**, and the **< >** rotate buttons.
3. Runway: the camera moves to the catwalk and you walk wearing the look. Voting is skipped quickly (there's nothing to vote on), then Results.
4. You go back to the lobby in your **own** outfit, with +coins and XP. Tap **Buy looks**: purchase prompts in Studio are test prompts and cost no Robux.

**Pairs and trio.** **Test tab → Clients and Servers → 2 Players → Start** (then do it again with **3 Players**).
- 2 players: each banner says "You're styling: Player2" and the reverse. You can't see your own mannequin.
- 3 players: trio rotation (1→2→3→1).
- On voting cards you can't heart your own look or the one you styled, and the most you can give is 3 hearts.

**Chaos rounds.** In `Config.luau` temporarily set `ChaosEveryRounds = 1` and `ChaosChance = 1`, then test with 3 players (Swap needs 3 or more). Put them back afterwards.

**Leaving mid-round.** With 3 players, close one player window during Styling, then during the Runway. The round keeps going and the stylist gets a "partner left" message. Nobody is stuck.

**Mobile.** **Test tab → Device** (emulator) → pick a phone (e.g. iPhone 14) in landscape, then Play. Check every button is easy to tap and nothing overlaps. Repeat with a tablet.

**Data.** Stop and Play again: coins and XP should still be there.

**Unit test (optional):** `luau tests/Pairing.spec.luau` (needs the standalone Luau CLI).

## Before launch: things only you can do

1. **Game passes + products** (Creator Dashboard → your game → Monetization):
   - Passes: *VIP* (399), *Pose Pack* (149).
   - Developer products: *Confetti Rain* (49), *Disco Mode* (49), *Sparkles/Confetti/Spotlight Entrance* (99 each), *Strut Walk* (99), *Glide Walk* (149).
   - Paste each ID into `Config.GamePasses` / `Config.DevProducts` (replace the `0`). Items with ID `0` show as "Soon".
2. **Walk animations and poses:** in `Config.Cosmetics`, fill `animationId` for Strut/Glide (the *walk* animation asset from a catalog animation pack) and the three poses (catalog emote IDs). Items with `0` are hidden.
3. **Sounds:** Toolbox → Audio, pick free sounds and put the IDs in `Config.Sounds`.
4. **Map:** build and decorate it, keeping these part names (anchored, CanCollide off for markers):
   ```
   Workspace.Map
     Lobby.Spawn                         where players return after a round
     Runway.Start / Runway.End            the walk (straight line)
     Runway.Camera                        runway camera, pointed at the catwalk
     Runway.Audience                      big floor part where players watch
     Runway.Lineup                        centre of the voting lineup (players spread along its X axis)
     Podium.First / Second / Third        results spots
     Booths.Booth_1.. .Stand / .Mannequin (optional: booths are auto-built far away if missing)
   ```
   Anything you don't build is created as a plain placeholder automatically.
5. Maturity & Compliance questionnaire, icon, thumbnails, description, then publish.

## Places where Roblox differs from the brief (please read)

1. **Renamed APIs.** Roblox now marks `ApplyDescription`, `GetProductInfo`, `SearchCatalog`, `CreateHumanoidModelFromDescription`, `IsFriendsWith` and `PlayEmote` as deprecated. The code uses the `…Async` versions (same behaviour).
2. **"One Color Only" can't be fully enforced.** The catalog API doesn't expose an item's colour, so the server can't check it. What's built: the chosen colour (e.g. "Red") is added to every catalog search that round. The rest is up to the players, which is part of the joke. If you'd rather drop this modifier, delete it from `Config.ChaosModifiers`.
3. **Friends "queue together".** There's no party/queue screen (that would need our own friend system, which the brief says to avoid). Instead, friends in the same server are paired automatically when possible.
4. **Shoes are bundles** in the catalog (left and right shoe), so they're picked and sold as one bundle.
5. **Walks.** Runway walks swap the `WalkAnimation` on the HumanoidDescription, so they must be catalog animation IDs (see step 2 above).
6. **Not built yet (post-launch in the brief):** rewarded video ads.

## Monetization rules (kept)

- Nothing random is sold. Every item has a fixed, visible outcome.
- `ProcessReceipt` records the purchase ID in the same save as the grant, and returns `PurchaseGranted` only after ProfileStore confirms the save. Retries never grant twice.
- Pass ownership comes only from `UserOwnsGamePassAsync` (cached). Coin prices come only from `Config`.
- Coins are earned only by playing.

## Safety (kept)

- No free text anywhere, not even a catalog search box. Themes come from `Config`.
- Hearts only. Nobody can see who voted for whom, and there's no last place (only looks with hearts reach the podium).
- A look can never change body parts, skin or head: only clothing, accessories, face and emote asset types are accepted (`Config.AssetRules`).

## Lint / format

```
selene src
stylua src
```
