# Style My Bestie: your launch checklist

Everything the code can't do for you, in the order to do it. Tick each box as you go.
All the settings you'll paste into are in **`src/shared/Config.luau`**. After every change there:
Rojo syncs it into Studio, then **File > Save to Roblox**.

---

## 1. Save the place (do this first, and after every Studio session)

- [ ] In Studio: **File > Save to Roblox** (Ctrl+S).
  The Blender building, Play Zone setup and booth template live in the place file, not in Git.
  If you skip this, the next server starts without them.

## 1b. Import the arcade hall (once)

- [ ] Studio (Rojo connected, `git pull` done): **File > Import 3D** > `assets/models/SMB_ArcadeHall.glb`.
      Set the scale unit to **Stud**, then Import.
- [ ] Make sure the game isn't running. **View > Command Bar**, paste, Enter:
      `require(game.ServerScriptService.Server.Tools.BlendImport).apply()`
- [ ] Play: walk through the west arch of the Customize/Team Up room. You should see four game
      platforms (Color Rush, Freeze Frame, Spin Sweep, Cover Star) and the champions screen.
- [ ] Stop, then **File > Save to Roblox**.

## 2. Game settings (Studio: Home > Game Settings)

- [ ] **Avatar > Avatar Type: R15** > Save. (Layered clothing and body types need R15.)
- [ ] **Security > Enable Studio Access to API Services: ON.** Coins, outfits, settings and
      leaderboards save in Studio too.
- [ ] **Security > Allow Third Party Sales: ON.** Without it, "Buy this look" can't sell catalog
      items from other creators, and those sales are where your commission comes from.
- [ ] Save.

## 3. Game passes (Creator Dashboard > your game > Monetization > Passes)

For each one: **Create a Pass**, upload any square image, name it, then set it **On Sale** at the
price. Copy its ID (the number in the pass's URL) and paste it into `Config.GamePasses` in place of
the `0`.

| Config key | Name on the dashboard | Price (Robux) |
|---|---|---|
| `StarterPack` | Starter Pack | 99 |
| `VIP` | VIP | 399 |
| `DoubleCoins` | 2x Coins | 299 |
| `PosePack` | Pose Pack | 149 |

Example: `VIP = { id = 123456789, price = 399, displayName = "VIP" },`

## 4. Developer products (Monetization > Developer Products)

For each one: **Create a Developer Product**, set the name and price, then copy its ID.

**Paste into `Config.DevProducts`** (replace `id = 0`):

| Config key | Name | Price |
|---|---|---|
| `Coins_Small` | Pile of Coins (500 coins) | 49 |
| `Coins_Medium` | Bag of Coins (1,200 coins) | 99 |
| `Coins_Large` | Chest of Coins (2,800 coins) | 199 |
| `Coins_Huge` | Vault of Coins (7,000 coins) | 449 |
| `MomentCoinShower` | Coin Shower | 99 |
| `MomentConfetti` | Confetti Rain | 49 |
| `MomentDisco` | Disco Mode | 49 |
| `MomentHearts` | Heart Rain | 49 |
| `MomentSnow` | Snow Day | 49 |
| `Tip_Small` | Small Tip | 25 |
| `Tip_Big` | Big Tip | 100 |
| `EntranceSparkles` | Sparkles Entrance | 99 |
| `EntranceConfetti` | Confetti Entrance | 99 |
| `EntranceSpotlight` | Spotlight Entrance | 99 |

**Paste into `Config.ProductIds`** (replace the `0`):

| Config key | Name | Price |
|---|---|---|
| `Walk_Stylish` | Stylish Walk | 99 |
| `Walk_Superhero` | Superhero Walk | 99 |
| `Walk_Ninja` | Ninja Walk | 99 |
| `Walk_Levitation` | Levitation Walk | 149 |
| `Walk_Toy` | Toy Walk | 99 |
| `Walk_Robot` | Robot Walk | 99 |
| `Walk_Elder` | Grandpa Shuffle Walk | 79 |
| `Walk_Zombie` | Zombie Walk | 79 |
| `Pose_Groove` | Groove Pose | 49 |
| `Pose_Spin` | Spin Move Pose | 49 |
| `Pose_Showstopper` | Showstopper Pose | 79 |
| `Aura_Angel` | Angel Glow Aura | 149 |
| `Aura_Hearts` | Heart Cloud Aura | 99 |
| `Aura_Galaxy` | Galaxy Swirl Aura | 199 |
| `Aura_Flame` | Flame Aura | 149 |
| `Aura_Electric` | Electric Aura | 149 |
| `Aura_Bubbles` | Bubble Pop Aura | 99 |

Notes:
- Anything still `0` shows "SOON" in the shop, so you can launch with only some of them.
- The dashboard price is what players actually pay; the shop shows the live price.
- **Test before creating:** in Studio, Play > **Admin** > the "Test: ..." buttons run each purchase
  without Robux.
- Optional: change prices any time on the dashboard; no code change needed.

## 5. Badges (Creator Dashboard > your game > Associated Items > Badges)

Create each badge (name, description, image), copy its ID and paste it into `Config.Badges`.
Badges left at `0` are simply not awarded. Note: Roblox may charge a small fee per badge after the
free ones each day.

| Config key | Suggested name | When it's awarded |
|---|---|---|
| `Welcome` | Welcome, Bestie! | First join |
| `FirstRound` | Runway Debut | Finished a round |
| `FirstPodium` | Podium Stylist | Styled a look that made the podium |
| `MinigameWin` | Play Zone Champ | Won a lobby minigame |
| `DashGold` | Speed Queen | Runway Dash gold medal |
| `Rank5` | Icon Status | Reached style rank 5 |
| `Wardrobe` | Closet Goals | Saved an outfit |

## 6. Admins (optional)

- [ ] You (the game owner) are already an admin. To add friends, put their user IDs (the number in
      their profile URL) in `Config.AdminUserIds`, e.g. `{ 12345678, 87654321 }`.

## 7. Music (optional)

The game already has sound effects and a built-in runway beat. To add real music:
- [ ] Studio: **Toolbox > Audio**, find a track you're allowed to use (Roblox-provided or your own
      upload), copy its ID.
- [ ] `Config.Sounds.LobbyMusic = 1234567890` for lobby music.
- [ ] `Config.Sounds.RunwayMusic = 1234567890` to replace the built-in runway beat.

## 8. Test before publishing

Use Studio's **Test** tab.
- [ ] **Solo:** Play (F5). Do a full round (styling, runway, results), visit every Play Zone game,
      save an outfit in the Dressing Room, buy something with coins.
- [ ] **Two players:** Test > Clients and Servers > 2 Players > Start. Check pairing ("You're
      styling: Player2"), runway reactions (tap the emojis while the other one walks), voting, and
      play Color Rush / Freeze Frame / Spin Sweep together (last one standing should win).
- [ ] **Three players:** same with 3 (trio rotation, Swap chaos round).
- [ ] **Phone:** Test > Device > pick a phone in landscape, Play. Every button should be easy to tap
      and nothing should overlap. Repeat with a tablet.
- [ ] **Saving:** Stop and Play again: coins, outfits and settings should still be there.
- [ ] Look at the Output window for red errors and send them to me if you see any.

## 9. Store page and publishing (Creator Dashboard)

- [ ] **Maturity & Compliance questionnaire** (required before the game can be public).
- [ ] **Icon** (512x512) and **thumbnails** (1920x1080; screenshots of the runway, the Play Zone at
      dusk and the Dressing Room work well. The in-game **Photo** button helps).
- [ ] **Description**: what the game is in one line, then the features (style your bestie blind,
      walk the runway, minigames, Wardrobe, weekend double coins).
- [ ] **Genre** and **max players per server** (8-12 works well for pairing).
- [ ] Set the game to **Public**.

## 10. After launch (to earn more)

- [ ] **Private servers:** Monetization > Private Servers > enable, e.g. 100 Robux/month. Friend
      groups love them for a game like this.
- [ ] **Premium Payouts** happen automatically (the shop already shows a Premium card).
- [ ] **Sponsored ads / Ads Manager** once players stick around (check Analytics > Retention).
- [ ] **Events:** edit `Config.Events` for holiday double-coin days, e.g.
      `{ name = "HALLOWEEN DOUBLE COINS", coinMultiplier = 2, days = { 1, 2, 3, 4, 5, 6, 7 } }`
      (remove it again afterwards; days 1-7 = Sunday-Saturday, UTC).
- [ ] Watch **Analytics > Economy** (coin sources and sinks) and **Monetization** to see what sells,
      then adjust prices.

## 11. Optional clean-up

- [ ] `ServerStorage > MapBackup` holds the old part-built lobby from the building import. Nothing
      uses it; delete it in Studio if you want (then save).
- [ ] The Output warning `rbxassetid://203785492 failed due to: Asset type does not match` comes
      from a Studio plugin, not the game. Safe to ignore.

---

### Quick reference: where things live

| What | Where |
|---|---|
| Prices, pass/product/badge IDs, events, rewards, minigame tuning | `src/shared/Config.luau` |
| Admin test buttons | In Play: the gold **Admin** button in the lobby |
| Saved player data | ProfileStore `PlayerData_v1` |
| Leaderboards | OrderedDataStores `StyleXP_v1` (Top Stylists) and `RunwayDashBest_v1` (Runway Dash) |
| Full feature docs | `README.md` |
