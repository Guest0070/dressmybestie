# Style My Bestie

Round-based Roblox fashion game: pair up, style your partner's mannequin blind, walk the runway, vote with hearts.

## Layout

```
src/server/   -> ServerScriptService.Server      (server-authoritative logic)
  Data/        ProfileStore wrapper (only place that touches saved data)
src/client/   -> StarterPlayerScripts.Client     (UI + input, sends intents only)
src/shared/   -> ReplicatedStorage.Shared        (Config, Types, Remotes)
```

Tune the game in `src/shared/Config.luau` (timings, limits, rewards, themes, chaos modifiers, pass IDs).

## One-time setup (Windows)

1. **Install Rokit** (toolchain manager): open PowerShell and follow https://github.com/rojo-rbx/rokit#installation.
   Close and reopen PowerShell after.
2. **Get the tools** — in the project folder:
   ```
   rokit install
   ```
   This installs rojo, wally, selene and stylua at the versions in `rokit.toml`.
3. **Get packages** (ProfileStore):
   ```
   wally install
   ```
   Creates `Packages/` and `ServerPackages/` (not committed to git).
4. **Install the Rojo Studio plugin:**
   ```
   rojo plugin install
   ```
   Restart Studio if it was open.

## Create the game in Studio (one time)

1. Open Roblox Studio → **New** → **Baseplate**.
2. **File → Publish to Roblox As…** → *Create new game* → name it "Style My Bestie" → **Create**.
3. **Home tab → Game Settings → Avatar**:
   - Avatar Type: **R15** (needed for layered clothing).
   - Click **Save**.
4. **Game Settings → Security** → turn on **Enable Studio Access to API Services** → **Save**.
   (Lets ProfileStore save data while testing in Studio.)
5. **File → Save to Roblox**.

## Every working session

1. In the project folder: `rojo serve`
2. In Studio: **Plugins tab → Rojo → Connect**. Code now syncs live from the files.

## Lint / format

```
selene src
stylua src
```

## Testing Day 1 (data + remotes)

1. `rojo serve`, connect in Studio.
2. **Test tab → Clients and Servers** → set **2 Players** → **Start**.
3. Three windows open (1 server, 2 players). In each **player** window open **View → Output**. You should see:
   ```
   [StyleMyBestie] Client started
   [StyleMyBestie] Coins: 0  XP: 0  Rank: 1  Daily ready: true
   ```
4. In the **server** window Output: `[StyleMyBestie] Server started`, and no red errors.
5. In the server window **Explorer**: `ReplicatedStorage → Remotes` contains the RemoteEvents.
6. **Test → Cleanup** to close everything.

If you see *"Couldn't load your data"* → step 4 of "Create the game" (API Services) is off.
