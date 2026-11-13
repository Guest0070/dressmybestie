# REDESIGN: what Style My Bestie should be

Phase 2. Written after AUDIT.md. Each item is marked **KEEP / CHANGE / CUT / ADD**, with a reason
and effort (**S** under an hour, **M** a few hours, **L** a day or more). "Done" means it shipped
in this pass; see CHANGELOG.md.

Honest limits: I have no player data for this game and cannot play it. Judgements about fun come
from reading the flow and from how round-based Roblox dress-up games generally work. Every number
below is a starting point to tune after watching real sessions (Creator Dashboard > Analytics).

## The one-line pitch

**You don't dress yourself. Your bestie does, and you don't see it until you're on the runway.**
That reveal is the joke, the share moment and the reason to bring a friend. Everything below is
judged by whether it gets players to that moment faster and makes it funnier.

---

## 1. Core loop

| Item | Verdict | Reason | Effort |
|---|---|---|---|
| Blind styling of a partner, reveal on the runway | **KEEP** | The only thing here another dress-up game doesn't have. | – |
| Styling up to 240 s, ends only when *everyone* is READY | **CHANGE → 120 s, and once half the stylists are READY the rest get 20 s** | One slow player was holding the server for 4 minutes. Waiting is where people quit. | S, done |
| Lobby countdown 30 s | **CHANGE → 20 s** | Dead time before the first round is the most expensive dead time. | S, done |
| Runway 9 s per look, walker only walks | **KEEP length, ADD a POSE button for the walker** | The walker is the star and has nothing to do. One big button that plays their pose gives them a job and a screenshot. | M, planned |
| Stars rating during the walk | **KEEP** | No separate voting phase, so no dead time. | – |
| One 5-star vote can beat ten 4.9s | **CHANGE → smoothed average for ranking** | Small audiences made the podium a coin flip. The shown score stays the real average. | S, done |
| Rating gives the rater nothing | **ADD 2 coins per look rated** | Pays people for watching the runway instead of going AFK; more ratings make results fairer. | S, done |
| Results 15 s, top 3 only, no last place | **KEEP** | Kind to a young audience, short. | – |
| Hearts voting mode (built, unused) | **CUT later** | Two voting systems double every text and test. Not now: removal touches 9 files and helps no player this week. | M, planned |
| Mid-round joiners wait for the next round | **KEEP, already softened** | They are moved to the audience and can rate and react. With 120 s styling the worst wait is ~3 min, not ~5.5. | – |

**Round length after the change (8 players):** 20 + 8 + (20 to 120) + 72 + 15 = **2.3 to 4 minutes**.

**What makes someone stay past round 1?** Three things, in order: (1) the reveal lands, so they
want to see what the next stranger does to them; (2) they got paid enough to want something in the
shop; (3) a quest is one step from done. Items 2 and 3 are in sections 4 and 5.

## 2. Funny factor

| Item | Verdict | Reason | Effort |
|---|---|---|---|
| 55 themes, many already silly ("Grandma at a Rave") | **KEEP, ADD 15 more absurd ones** | Themes are free content. The odd ones get the laughs; the plain ones ("First Date") don't. | S, done |
| Chaos rounds on every 4th round at 60% | **CHANGE → every 2nd round at 70%, never round 1** | The funniest rounds happened about once per half hour. Round 1 stays plain so new players learn the normal game first. | S, done |
| Worst Outfit Wins, Swap Mid-Round, One Color Only | **KEEP** | All three are good. | – |
| New chaos: **Speed Round** (45 s to style) | **ADD** | Panic outfits are funny and it shortens the round. Data-driven, tiny code. | S, done |
| New chaos: **Blindfold** (catalog thumbnails hidden) | **ADD later** | Very funny, but needs a catalog UI change that must be seen in Studio first. | M, planned |
| Emoji reactions over the walker | **KEEP** | Cheap, loud, social. | – |
| Runway name tag "X, styled by Y" | **KEEP** | Puts the blame where it belongs. That is the joke. | – |
| Photo button on runway/results | **KEEP** | Free marketing if screenshots get shared. | – |
| Stylist's reaction cam / "what were you thinking" moment | **ADD later** | Nice, but camera work can't be judged without playing. | L, not planned |

## 3. Social

| Item | Verdict | Reason | Effort |
|---|---|---|---|
| Roblox friends are paired with each other | **KEEP** | This *is* bestie mode. It already works. | – |
| Friend-in-round coin bonus 10% | **CHANGE → 25% and call it "Bestie bonus"** | 10% of ~40 coins is invisible. It has to be big enough to notice on the reward toast. | S, done |
| Invite button | **KEEP**, move to phase 2 of onboarding | Works. Should also be offered at the moment it matters: "Waiting for players (1/2)". | S, planned |
| Party / private servers | **ADD via dashboard, no code** | Private servers at a low monthly price are steady income from friend groups. Checklist item. | S, Divyansh |
| Duo-only themes or 2v2 teams | **CUT (don't build)** | Needs 4+ friends online together; a zero-budget launch won't have that. | – |

## 4. Retention

| Item | Verdict | Reason | Effort |
|---|---|---|---|
| 7-day login streak | **KEEP** | Standard and working. | – |
| Daily quests (6) and achievements (17) | **KEEP** | Good spread; the "getting started" ones double as a tutorial. | – |
| 10 ranks with cosmetic unlocks | **KEEP** | Gives XP a point. | – |
| New players start with 0 coins | **CHANGE → 150 welcome coins** | Lets them buy the cheapest title or entrance *before* round 1 ends, which teaches the shop and gives them something to show off. | S, done |
| 10 coins for playing a round | **CHANGE → 25** | With ~30–60 coins a round the first 150-coin item took 3–5 rounds. Now 2–3. Top items (1200) still take a few sessions. | S, done |
| Weekly featured theme, weekend double coins | **KEEP** | Rotates with no new code. | – |
| Seasonal content | **ADD by config only** | `Config.Events` and `Config.FeaturedThemes` already support it. Put real dates in before each holiday. | S, Divyansh |
| Coin caps that reset on rejoin | **CHANGE → saved per day** | A farm undercuts the coin packs. | M, done |

## 5. Monetization (fair, cosmetic only)

Ranked by likely revenue for a small new game. Reasoning, not data:

1. **"Buy this look" catalog commission.** Costs nothing to maintain, fits the game exactly (you
   just saw the outfit on a real avatar), and scales with every round. **KEEP**, and it is why
   *Allow Third Party Sales* must be on.
2. **Starter Pack (99 R$).** Cheapest pass, biggest visible value, shown first. **KEEP.**
3. **VIP (399 R$).** Extra item slots are a real styling advantage in *range*, not in votes.
   **KEEP**, watch that VIP-only themes don't make non-VIP rounds feel second-class.
4. **Server-wide moments (49–99 R$).** Impulse buys with an audience, repeatable. **KEEP.**
5. **Premium Payouts.** Automatic; grows with time played by Premium members. **KEEP.**
6. **Coin packs.** Only earn if coins feel scarce *and* worth having. Raising round pay makes
   packs slightly less needed but makes the shop get used at all. **KEEP, re-check after launch.**
7. **Walks / poses / auras (49–199 R$ each, 17 products).** Long tail. **KEEP**; cut prices on
   whatever has zero sales after a month.
8. **2x Coins (299 R$).** Worth less than its price until the coin shop is deeper. **KEEP, lowest
   expectation.**
9. **Tips.** Pocket change. **KEEP**, it's free.

Rules that stay: nothing random is sold, no pressure timers, coins never buy votes, every price is
shown before the prompt. **Do not add:** loot boxes, paid re-rolls of themes, paid extra votes.

## 6. Onboarding (understand in 10 seconds, no reading)

| Item | Verdict | Reason | Effort |
|---|---|---|---|
| "How to play" card: four paragraphs | **CHANGE → four short lines, one emoji each** | Kids don't read cards. The real tutorial is the first round. | S, done |
| Nothing tells a first-timer what to tap in the booth | **ADD a first-round hint over the catalog** ("👆 Tap clothes to dress NAME, then READY") | The only place a new player can get stuck. Shown until they have played one round. | S, done |
| Round 1 is always a plain round | **ADD** (see chaos change) | Learn the normal game first. | S, done |
| Achievements for trying the Dressing Room, a minigame, the Wardrobe | **KEEP** | Soft tutorial with a reward. | – |

## 7. Mobile first

| Item | Verdict | Reason | Effort |
|---|---|---|---|
| Lobby buttons kept compact (36 px floor) | **KEEP, on purpose** | Divyansh asked for smaller buttons after seeing them cover the screen. 36 px is below the usual 44 pt guideline; I'm leaving it and flagging it. If testers miss taps, raise `Theme.MinTouch` to 44: one number. | – |
| Wardrobe delete 26×36, Shop TRY 52×28 | **CHANGE → 36×36 and 56×36** | These two were below even the game's own floor. | S, done |
| Catalog cells ~78 px, READY 120×44 | **KEEP** | Comfortable. | – |
| Catalog has no item names | **KEEP** | Pictures are enough and names would shrink the cells. | – |
| Safe areas | **KEEP** | Both toolkits respect the device safe area. | – |
| Booths 600 studs away with streaming on | **CHANGE → ask Roblox to load the area before teleporting** | Phones could arrive in an empty room. | S, done |
| Controller / console | **CUT from launch scope** | Would need selection wiring on 12 screens. Launch on phone + PC + tablet, list console as unsupported. | L, not planned |

## 8. Discoverability

**Title:** `Style My Bestie 👗 [Dress Up]`. Keep the real name first; the bracket carries the search
term people actually type. Rename the experience on the dashboard (it still says "Dress My Bestie").

**Icon concept (512×512):** two avatars back to back, one in a perfect gown, one in a chicken suit
with a tiara, hot-pink background, no text. The contrast *is* the pitch. Build it in Studio with
two dressed dummies and a screenshot; no outside art needed.

**Thumbnails (1920×1080, make 3):**
1. The reveal: a player on the runway in a ridiculous outfit, audience emoji flying. Text: "YOUR BESTIE DRESSES YOU".
2. The booth: catalog open, mannequin half-dressed, timer at 0:10.
3. The podium with confetti. Text: "WORST OUTFIT WINS?!"

**Description (first two lines are what search shows):**
> You don't pick your outfit. Your bestie does! 👗 Style a friend in secret, then walk the runway
> in whatever THEY chose for you. Rate the looks, win the podium, laugh at the disasters.
>
> ⭐ New silly theme every round · 🎲 Chaos rounds: Worst Outfit Wins, Speed Round, Swap!
> 👯 Bestie bonus coins when you play with friends · 🎮 Minigames between rounds
> 🎁 Daily rewards, quests and free unlocks

**Genre:** Roleplay & Avatar Sim > Dress Up. **Max players:** 10 (pairs fill fast, runway stays ~90 s).

TODO (art, zero cost): the icon and three thumbnails above. Source: Studio screenshots of the game
itself (Shift+P freecam), composed in any free editor (Photopea, Canva free tier).

## 9. Art direction

**KEEP** the plum / hot-pink / gold UI and the Blender building. They are consistent and already
built. **CHANGE** only one thing in code: three separate colour tables (UI, effects, minigames)
should become one. That is tidy-up, not launch work (M, planned). I can't judge lighting or the
building from here; send screenshots and I'll say what I'd change.

## 10. Where I disagree with earlier choices

- **4-minute styling.** Too long for the audience this game is for. Cut in half, and stop letting
  one player hold everyone.
- **Chaos as a rare treat.** The chaos rounds are the best content in the game; they should be
  about half of all rounds.
- **Building five minigames before the core loop was tuned.** They are fine, but they are where
  most of the code and the risk is, and they are not why anyone will tell a friend about the game.
  I would not add a sixth.
- **Two voting systems.** Pick one. Stars is the right one (no extra phase).
- **Code-built world next to the Blender world.** Once the building is saved in the place, the
  placeholder plaza is dead weight. Keep it only until launch as a safety net.
