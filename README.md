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
| Voting | `src/server/Voting/Voting.luau` | 1-5 stars per look while it walks (or hearts, up to 3, with `Config.VotingMode = "Hearts"`); no voting for yourself or your own styling, never reveals who voted |
| Rewards | `src/server/Round/Rewards.luau` | Fixed coins and XP; hearts credit the stylist, podium bonus |
| Shop | `src/server/Monetization/*` | Game passes (cached), idempotent ProcessReceipt, coin shop, equip, lobby moments |
| Analytics | `src/server/Analytics.luau` | Funnel: joined → 1st round started → 1st finished → 2nd finished; purchase + coin events |
| Client UI | `src/client/UI/*` | HUD, catalog browser, voting cards, results podium + "Buy this look", shop. Mobile-first |
| Client stage | `src/client/Stage.luau`, `Moments.luau` | Booth/runway cameras, movement lock, pose at end of walk, confetti/disco |

The server makes every decision. Clients only send requests, and the server checks each one.

## Everything in the game

**The round:** lobby → pairing (friends paired together, trio for odd numbers) → theme reveal → up to 4 minutes of
styling in a private booth (everyone taps READY to finish early) → runway (follow camera, camera flashes, name tags, entrance effects) → hearts-only
voting → results (podium reveal 3rd→1st, confetti, 1st/2nd/3rd tags, "Buy this look"). Chaos rounds: Worst
Outfit Wins, Swap Mid-Round, One Color Only. 55 themes + a weekly featured theme. AFK players sit out.

**Lobby (things to do between rounds):**
- Dressing Room kiosk: dress your own avatar from the catalog, then "Buy these".
- Shop kiosks: Boutique (entrances), Trail Bar, Title Studio, VIP Lounge.
- **Spawn:** players arrive inside the Blender building's hall, just inside the foyer doors,
  facing the runway stage (and come back there after every round).
- **Play Zone:** the plaza outside the foyer doors, in the building's materials (white and black
  marble, champagne metal, warm LEDs): a black marble path from the doors through the PLAY ZONE arch
  to a fountain, planters, light posts and a how-to-play board. Everything to do between rounds is
  here, and the **GAMES** button lists it all with a GO button:
  - *Color Rush* (north-east): floating tiles under a truss with a 4-sided colour screen. A colour
    is called, the wrong tiles blink, then drop. 15 waves that speed up; from wave 4 twists:
    SHUFFLE (colours change mid-wave), MEMORY (colours hide before the call), FAKE OUT (the call
    changes), TWO COLORS; from wave 11 the outer ring falls away for good.
  - *Freeze Frame* (north-west): a paparazzi photo shoot on a disco stage. DANCE (beat + light show),
    then FREEZE! (cameras flash; move and you're "CAUGHT MOVING!"), JUMP FOR THE CAMERA! (from
    round 3; don't jump and you're out) or a FREE... STYLE! fake-out. The winner goes on the COVER
    STAR board.
  - *Spin Sweep* (south-west): jump the sparking arm or get flung off; REVERSE! and SURGE! events,
    and a second arm (a cross) at 22s. Survive 60s or be the last one on.
  - *Runway Dash* (east): a timed course over a glowing pool: hurdles, vanishing tiles, a spinning
    bar, a jump pad, sliding blockers, a finish catwalk with flashing cameras. Two checkpoints (fall
    in the pool = back to your checkpoint), live stopwatch with splits, medals (Gold 22s / Silver
    28s / Bronze 36s, 30/20/10 coins once per 10 min), saved personal best, this server's board and
    an all-time global top 10 (OrderedDataStore `RunwayDashBest_v1`).
  - *Sky Obby* (west): 16 jumps into the sky with two checkpoints (fall = back to your checkpoint),
    +40 coins once per 10 min.
  - Dance floor with disco ball, bounce pads, 13 collectible gems (+2 each, capped per visit).
  Round games (Color Rush, Freeze Frame, Spin Sweep): step on to join; a countdown (3-2-1-GO on
  screen) starts it for everyone on it. Winners get fireworks, a shout-out to everyone nearby, +15
  coins (max 6 paid wins an hour, `Config.Minigames`), win streaks, quest progress and a spot on
  the PLAY ZONE CHAMPIONS board. The server decides who fell, moved or got hit; the banner shows
  the call, a countdown bar and who's left, and the lobby buttons step aside while you play.
  All sounds are Roblox's built-in ones (no uploads).
- **The world:** paved ground with boulevards, street lamps and trees, a neon city skyline, dusk
  lighting (`Config.Environment`).
- Top Stylists board, Hall of Fame statues of last round's top 3 (walk up → "Buy this look").

**Social + extras:**
- **Runway reactions:** while a look walks, everyone else gets ❤️🔥😍😂👑 buttons; reactions float
  up over the model for the whole server (rate limited, nothing scored).
- **Wardrobe:** in the Dressing Room, save what you're wearing to a slot (3, VIP 6) and wear it
  again later. Saved items are re-checked by the server every time.
- **Events:** `Config.Events` (default: DOUBLE COINS WEEKEND on Sat/Sun UTC) multiplies round coins
  and shows a banner in the lobby.
- **Friend bonus:** +10% round coins when a Roblox friend is in the round. The reward toast lists
  every bonus that applied.
- **Round warning:** 10 seconds before a round starts, a toast + ping (so minigame players aren't
  surprised).
- **ALL-TIME TOP STYLISTS** board (OrderedDataStore `StyleXP_v1`) next to this server's board.
- **Badges:** `Config.Badges` (Welcome, FirstRound, FirstPodium, MinigameWin, DashGold, Rank5,
  Wardrobe). Create them on the dashboard and paste the IDs; 0 = skipped.
- **Settings are saved** to the profile: Music, Sound effects and **Flashing effects** (turns off
  camera flashes and screen flashes for players sensitive to flashing light).
- **Sound:** every slot in `Config.Sounds` now has a built-in Roblox sound, and the runway plays a
  built-in beat (kick, hi-hat, clap) unless `RunwayMusic` has a track ID.
- 5 new "getting started" achievements (try the Dressing Room, play a minigame, save an outfit,
  win a Dash medal, send 25 reactions).

**Progression:** coins + style XP, 10 ranks with free unlocks, daily login streak (50 → 200 coins),
5 daily quests, 9 achievements, overhead name tag with title + rank, coins/rank in the player list,
rank-up celebration.

**Shop (all fixed items, nothing random):** 10 entrance effects, 8 trails, 10 titles, walks, poses,
VIP pass, Pose Pack, lobby moments (confetti rain / disco mode with your name), Premium +10% coins.

**Also:** How to Play card, Invite Friends, Photo button (share/save a screenshot), Admin panel,
mobile-first UI.

### Newer systems

- **Skin Tone + Body Type booths** (glass tubes near spawn): walk in and the panel opens; walk out and it
  closes. 14 skin swatches and 6 body types (Classic, Slim, Tall, Petite, Sturdy, Model), saved to your
  profile, re-applied on respawn, and exactly what walks the runway. Layered clothing re-wraps to the new
  body; set `Config.BodySwapClearsOutfit = true` to strip the outfit on a body swap instead. For real
  feminine/masculine packages, add catalog body part IDs to a body type's `bodyParts` in Config.
- **Voting mode** (`Config.VotingMode`): `"Stars"` (default) = the audience rates each look 1–5 stars while
  it walks; best average wins. `"Hearts"` = the original hearts-only voting after the runway. Your brief
  asked for hearts only (no low scores for kids), so switch back any time with that one line.
- **Runway cinematic:** wide tracking → orbit → low hero angle → close-up, per walker.
- **Walks & poses:** real Roblox animation-pack walks (Stylish, Superhero, Ninja, Levitation, Toy, Robot,
  Zombie, Grandpa Shuffle; Cartoony + Bubbly for coins) with live previews. During your walk the Animate
  script's walk/idle animations are swapped, then restored. Poses (Wave/Point/Cheer in Pose Pack, dances
  for Robux, Giggle for coins) play at the end of the runway.
- **Auras:** 8 particle/trail auras (6 for Robux, Golden with VIP, Starlight free at rank 5), "Try" preview,
  equip/unequip, visible on the runway. Templates live in `ReplicatedStorage.Auras` (edit or add your own).
- **Spectator mode:** "Spectate" button in the lobby. Spectators keep using the lobby while others style,
  then watch from the audience and rate; they never walk. Idle players are switched to spectating.
- **Purchases save** in ProfileStore (DataStore underneath, with session locking), so unlocks survive
  rejoining. Robux items need their product IDs: paste them into `Config.ProductIds` (walks, poses,
  auras) and `Config.DevProducts` / `Config.GamePasses` (VIP, Pose Pack, entrances, moments).

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

## Blender building (assets/models)

`Style_My_Bestie_Final.blend` is exported to `assets/models/SMB_*.glb`, one file per area: Hall,
Shop, VIP Lounge, Hall of Fame, Customize/Team Up, Runway Stage, Dressing Room, VIP Ramp.
`Style_My_Bestie_Arcade_Hall_1.blend` adds the arcade hall as `SMB_ArcadeHall.glb`. Meshes are
split by material (a Roblox mesh has one colour) and anything over 19k triangles was reduced (Roblox
limit 20k). 1 Blender metre = 1 stud. The scripts that did this are in `tools/blender/`.

**Put it in the game (once, in Studio):**
1. Open the place, Rojo connected, `git pull` done.
2. **File > Import 3D**, pick all 9 `.glb` files in `assets/models` (already imported the other 8?
   then just `SMB_ArcadeHall.glb`). In the import window set the
   scale unit to **Stud**, then Import. (Where they land doesn't matter.)
3. Press **Stop** if the game is running (the command does nothing during Play). **View > Command Bar**, paste, Enter:
   `require(game.ServerScriptService.Server.Tools.BlendImport).apply()`
4. Play to try it, then **File > Save to Roblox**.

`apply()` puts the building just north of the lobby plaza (walk in through the foyer doors), sets
colours, materials, glass, neon, collisions and the Blender lights, and wires the game to it:
runway + podium on the stage, skin/body booths in the Customize capsules, shop kiosks in the shop bays,
VIP kiosk in the lounge, Dressing Room kiosk at the Team Up console, and every styling booth becomes a
copy of the private dressing room (`ServerStorage.SMB_BoothTemplate`). The arcade hall sits west of the
Customize/Team Up room (through its west arch). Once it's imported, Color Rush, Freeze Frame and Spin Sweep
move onto its platforms, Cover Star opens on the fourth, and the champions board shows on its big screen. An old `Workspace.LobbyEnvironment`
is moved to `ServerStorage.MapBackup` (not deleted). Ctrl+Z undoes the whole thing.
Every piece is snapped to its exact Blender position and size and anchored, so it doesn't matter where
Studio dropped the models. If you press Play before running the command, the server does the same setup
for that play session (walls are walk-through then); run the command in Edit mode and save to keep it.
Don't want the lights? `apply({ lights = false })`. Keep the old lobby? `apply({ stashOld = false })`.

## Design the UI yourself (Studio): LobbyUI, ShopUI, SettingsUI

The lobby screen is built by code, but you can replace it with one you design in Studio. The code then
only makes your buttons work. It finds them by **Name**, so keep the names.

1. Play. In Explorer open **Players > (you) > PlayerGui > LobbyUI**, select it, **Ctrl+C**.
2. Stop. Select **StarterGui**, **Ctrl+V**. Untick **ResetOnSpawn** on it.
3. Edit it with the normal Studio tools or a free plugin (e.g. AutoScale Lite). Move, resize, recolour,
   change fonts, swap the coin/XP circles for images (set **Icon.Image**), delete the sheen gradients...
   A button's colours in Studio become its normal look; hover, pressed and selected effects are added on top.
4. **File > Save to Roblox.** Rojo doesn't touch StarterGui, so your design lives in the place file.

Names the code needs (anywhere inside LobbyUI): `TopBar`, `Lobby` (hidden outside the lobby),
`RoundStatus` with `Headline` + `Value` labels, `Coins` and `StyleXP` frames each with a `Value` label
(optional `Icon`, `Glyph`, and for XP `Progress` > `Fill`), and buttons `Settings`, `JoinRandom`,
`Spectate`, `Customize`, `Shop`, `Quests` (with a `Badge` frame), `Daily`, `BuyLooks`, `Admin`, `Invite`,
`HowToPlay`. Text that changes (coins, timer, JOIN RANDOM/JOINED) is set by code.
If a name is missing, Output says which one and the game uses the built-in UI instead.
To go back to the built-in UI, delete StarterGui.LobbyUI.

The same steps work for **ShopUI** (open the shop once during Play so it exists, then copy it) and
**SettingsUI**. Names they need are listed at the top of `src/client/UI/ShopUI.luau` and
`SettingsUI.luau`. In the shop, every item is a copy of the hidden `CardTemplate`: style that one card.

## Admin panel

A gold **Admin** button in the lobby opens fixed buttons: start round now, skip phase, force a chaos
mode for the next round, +coins, +XP, daily reward again, reset my data, and (Studio only) test
buttons for every coin pack, tip, lobby moment and pass.
Who can see it: everyone in Studio, the game owner, and user IDs in `Config.AdminUserIds`.
The server re-checks every command, so a hacked client can't use it.

## Before launch: things only you can do

1. **Game passes + products** (Creator Dashboard → your game → Monetization). Create each one with
   this name and price, then paste its ID into `Config.luau` in place of the `0`. Anything still `0`
   shows as "SOON" in the shop, so you can launch with only some of them.
   - **Game passes** (`Config.GamePasses`): *Starter Pack* (99), *VIP* (399), *2x Coins* (299), *Pose Pack* (149).
   - **Coin packs** (`Config.DevProducts`, `Coins_*`): *Pile of Coins* 500 coins (49), *Bag of Coins* 1,200 (99),
     *Chest of Coins* 2,800 (199), *Vault of Coins* 7,000 (449).
   - **Lobby moments** (`Moment*`): *Coin Shower* (99), *Confetti Rain*, *Disco Mode*, *Heart Rain*, *Snow Day* (49 each).
   - **Tips** (`Tip_*`): *Small Tip* (25), *Big Tip* (100).
   - **Unlocks** (`Entrance*` in `Config.DevProducts`, the rest in `Config.ProductIds`): Sparkles/Confetti/Spotlight
     entrances (99 each), 8 walks (79-149), 3 poses (49-79), 6 auras (99-199).
   - The price you set on the dashboard is what players pay; the shop shows the live price.
   - Test every item before it has an ID: in Studio, **Admin → Test: …** runs the real grant without Robux
     (passes last for that play session only).
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
   Anything you don't build is created automatically: a decorated placeholder (neon catwalk,
   spotlights, a backdrop showing the theme, bleachers, lobby title sign). Its decorations sit in
   `Decor` models, so you can delete them when you build your own.
5. Maturity & Compliance questionnaire, icon, thumbnails, description, then publish.

## Places where Roblox differs from the brief (please read)

1. **Renamed APIs.** Roblox now marks `ApplyDescription`, `GetProductInfo`, `SearchCatalog`, `CreateHumanoidModelFromDescription`, `IsFriendsWith` and `PlayEmote` as deprecated. The code uses the `…Async` versions (same behaviour).
2. **"One Color Only" can't be fully enforced.** The catalog API doesn't expose an item's colour, so the server can't check it. What's built: the chosen colour (e.g. "Red") is added to every catalog search that round. The rest is up to the players, which is part of the joke. If you'd rather drop this modifier, delete it from `Config.ChaosModifiers`.
3. **Friends "queue together".** There's no party/queue screen (that would need our own friend system, which the brief says to avoid). Instead, friends in the same server are paired automatically when possible.
4. **Shoes are bundles** in the catalog (left and right shoe), so they're picked and sold as one bundle.
5. **Walks.** During your runway walk the server swaps the Animate script's walk/idle animations, then puts the originals back. Walk IDs in `Config.Cosmetics` are Roblox animation-pack IDs.
6. **Not built yet (post-launch in the brief):** rewarded video ads.
7. **Stars instead of hearts.** The brief asked for hearts only; voting now uses 1-5 stars per look (requested later). `Config.VotingMode = "Hearts"` switches back. Either way nobody sees who voted what and there's no last place.
8. **Lighting.Technology is deprecated.** Roblox replaced it with `LightingStyle` + `PrioritizeLightingQuality`, which scripts can't set; LAUNCH_CHECKLIST step 2b sets them in Studio.

## Monetization rules (kept)

- Nothing random is sold. Every item has a fixed, visible outcome.
- `ProcessReceipt` records the purchase ID in the same save as the grant, and returns `PurchaseGranted` only after ProfileStore confirms the save. Retries never grant twice.
- Pass ownership comes only from `UserOwnsGamePassAsync` (cached). Coin prices come only from `Config`.
- **Changed:** the brief said coins are earned only by playing. Coins can now also be bought (coin
  packs, Starter Pack, Coin Shower), because coin packs are usually a Roblox game's biggest earner.
  Coins still only buy cosmetics, never an advantage in voting. To go back, leave the `Coins_*`
  product IDs at `0` (the COINS tab then only shows "SOON") or delete those entries.
- One-time grants can't repeat: the Starter Pack's coins are recorded in `passGrants` in the same
  save as the coins.
- No fake timers, "limited time" pressure or streak-loss prompts: the shop only opens when a player
  taps it, and "not enough coins" leads to the coin packs instead of a dead button.

## Money: what's in the game

| What | How it earns |
|---|---|
| Coin packs (COINS tab, "+" on the coins pill) | Every coin item in the shop leads here when a player is short |
| Starter Pack pass | Cheap first purchase: 1,500 coins + exclusive trail and title, once |
| 2x Coins pass | Doubles round coins (stacks with Premium's +10%) |
| VIP pass | Extra item slots, VIP themes, gold trail/aura/title, +50% daily reward |
| Lobby moments | Server-wide effects with the buyer's name; Coin Shower gives everyone 25 coins |
| Walks, poses, auras, entrances | Permanent cosmetics, shown on the runway to everyone |
| Tips | Supporter title |
| "Buy this look" (results / Hall of Fame / Dressing Room) | Roblox pays the game a commission on catalog items sold in-game (needs **Allow Third Party Sales**) |
| Roblox Premium card | Premium Payouts: Roblox pays for time Premium members spend in the game |

Also worth doing on the dashboard: **Private servers** (Monetization → Private Servers, e.g. 100 Robux/month)
so friend groups can play together, and **Sponsored ads** once the game retains players.

## Safety (kept)

- No free text anywhere, not even a catalog search box. Themes come from `Config`.
- Stars (or hearts) only, no text. Nobody can see who voted for whom, and there's no last place (only the top 3 reach the podium).
- Flashing effects: at most 3 per second in total, off with Settings > Flashing effects or Roblox's Reduced Motion setting.
- A look can never change body parts, skin or head: only clothing, accessories, face and emote asset types are accepted (`Config.AssetRules`).

## Lint / format

```
selene src
stylua src
```
