"""The sound list for Style My Bestie: one entry per audio file the game needs.

Each entry maps one generated (or external) file to the Config.Sounds keys it fills
(src/shared/Config.luau). Several keys can share one file, which keeps Roblox audio
uploads (a monthly quota) to a minimum.

Fields:
  id          file stem, unique
  category    UI | Gameplay | Runway | Results | Rewards | Music
  keys        Config.Sounds keys this file fills
  events      gameplay events that play it (file:line references live in the audit report)
  (upload priority is worked out by process_sfx.py from the current Config.Sounds values:
   a file that fills a silent key comes first, optional replacements and fallbacks after.)
  loop        True for music: processing makes the end flow into the start
  max_s       longest acceptable duration (seconds); longer files are flagged
  rms_db      loudness target (RMS dBFS) for normalisation
"""

UI, GAMEPLAY, RUNWAY, RESULTS, REWARDS, MUSIC = "UI", "Gameplay", "Runway", "Results", "Rewards", "Music"

CATALOG = [
    # UI
    dict(id="ui_click", category=UI, keys=["Click"],
         events=["Any button or toggle pressed (Kit.button, Components)"], max_s=0.25, rms_db=-20),
    dict(id="ui_phase_change", category=UI, keys=["PhaseChange"],
         events=["Round phase changes (HUD.refreshRound)"], max_s=1.0, rms_db=-20),
    dict(id="ui_alert", category=UI, keys=["Alert"],
         events=["Lobby: round starts in 10 seconds (HUD.roundAlert)"], max_s=1.0, rms_db=-19),
    dict(id="ui_time_warning", category=UI, keys=["TimeWarning"],
         events=["Styling or voting timer reaches 10 seconds (HUD.timeWarning)"], max_s=1.0, rms_db=-19),
    dict(id="ui_ready", category=UI, keys=["Ready"],
         events=["Stylist taps READY (Catalog)"], max_s=0.8, rms_db=-20),
    # Gameplay
    dict(id="gp_theme_reveal", category=GAMEPLAY, keys=["ThemeReveal"],
         events=["Theme reveal card appears (HUD.refreshRound, ThemeReveal phase)"], max_s=2.0, rms_db=-19),
    dict(id="gp_heart", category=GAMEPLAY, keys=["Heart"],
         events=["Player gives a heart (VotingUI) or a star rating (StarsUI)"], max_s=0.6, rms_db=-20),
    dict(id="gp_pop", category=GAMEPLAY, keys=["Reaction", "MinigamePop", "MinigameSnap"],
         events=["Emoji reaction sent (ReactionsUI)", "Runway Dash split (MinigameFx)"], max_s=0.4, rms_db=-20),
    dict(id="gp_tick", category=GAMEPLAY, keys=["MinigameTick"],
         events=["Minigame 3-2-1 countdown (Minigames/init)"], max_s=0.25, rms_db=-21),
    dict(id="gp_go", category=GAMEPLAY, keys=["MinigameGo"],
         events=["Minigame GO, Color Rush waves, Spin Sweep start"], max_s=1.0, rms_db=-18),
    dict(id="gp_drop", category=GAMEPLAY, keys=["MinigameDrop"],
         events=["Color Rush tiles drop"], max_s=1.2, rms_db=-19),
    dict(id="gp_out", category=GAMEPLAY, keys=["MinigameOut"],
         events=["Player knocked out of a minigame (sent to that player only)"], max_s=1.2, rms_db=-19),
    dict(id="gp_hit", category=GAMEPLAY, keys=["MinigameHit"],
         events=["Runway Dash / Spin Sweep player hit"], max_s=0.5, rms_db=-18),
    dict(id="gp_whoosh", category=GAMEPLAY, keys=["MinigameWhoosh"],
         events=["Spin Sweep arm passes near the player (MinigameFx)"], max_s=0.8, rms_db=-20),
    dict(id="gp_launch", category=GAMEPLAY, keys=["MinigameLaunch", "LobbyMoment"],
         events=["Spin Sweep launch pads", "Bought lobby moment (confetti/disco)"], max_s=2.0, rms_db=-19),
    dict(id="gp_switch", category=GAMEPLAY, keys=["MinigameSwitch"],
         events=["Color Rush colour switch, Cover Star round, Runway Dash checkpoint"], max_s=0.6, rms_db=-20),
    dict(id="gp_camera_flash", category=GAMEPLAY, keys=["MinigameFlash"],
         events=["Freeze Frame photo / paparazzi flashes (MinigameFx)"], max_s=0.8, rms_db=-20),
    # Runway
    dict(id="rw_entrance", category=RUNWAY, keys=["RunwayEntrance"],
         events=["A look starts its runway walk (RunwayEffect remote, Stage)"], max_s=1.6, rms_db=-20),
    dict(id="rw_vip_entrance", category=RUNWAY, keys=["VipEntrance"],
         events=["A VIP's look starts its runway walk (RunwayEffect remote, Stage)"], max_s=2.2, rms_db=-19),
    dict(id="rw_beat_kick", category=RUNWAY, keys=["BeatKick"],
         events=["Built-in runway beat and Freeze Frame dance beat (Audio, MinigameFx)"], max_s=0.5, rms_db=-16),
    dict(id="rw_beat_hihat", category=RUNWAY, keys=["BeatHiHat"],
         events=["Built-in runway beat and Freeze Frame dance beat (Audio, MinigameFx)"], max_s=0.2, rms_db=-22),
    dict(id="rw_beat_clap", category=RUNWAY, keys=["BeatClap"],
         events=["Built-in runway beat (Audio)"], max_s=0.4, rms_db=-19),
    # Results
    dict(id="rs_podium", category=RESULTS, keys=["Podium"],
         events=["3rd and 2nd place rows appear (ResultsUI)"], max_s=1.5, rms_db=-19),
    dict(id="rs_winner", category=RESULTS, keys=["Winner", "MinigameWin"],
         events=["1st place row appears (ResultsUI)", "Minigame winner (Minigames/init, Runway Dash)"],
         max_s=3.0, rms_db=-18),
    dict(id="rs_rank_up", category=RESULTS, keys=["RankUp"],
         events=["Reward summary with a rank up (HUD.showRewards)"], max_s=2.5, rms_db=-18),
    # Rewards
    dict(id="rw_coins", category=REWARDS, keys=["Coins"],
         events=["Round reward summary arrives (HUD.showRewards)"], max_s=1.2, rms_db=-19),
    dict(id="rw_claim", category=REWARDS, keys=["QuestClaim", "DailyReward"],
         events=["Quest reward claimed (QuestsUI)", "Daily reward claimed (LobbyUI)"], max_s=1.4, rms_db=-19),
    dict(id="rw_purchase", category=REWARDS, keys=["Purchase"],
         events=["Cosmetic bought with coins (ShopUI)"], max_s=1.2, rms_db=-19),
    dict(id="rw_equip", category=REWARDS, keys=["Equip", "OutfitSaved"],
         events=["Cosmetic equipped (ShopUI)", "Outfit saved to the Wardrobe (WardrobeUI)"], max_s=0.8, rms_db=-20),
    # Music
    dict(id="mu_lobby_loop", category=MUSIC, keys=["LobbyMusic"], loop=True,
         events=["Lobby phase background music (Audio.startLobbyMusic)"], max_s=60, rms_db=-21),
    dict(id="mu_runway_loop", category=MUSIC, keys=["RunwayMusic"], loop=True,
         events=["Runway and voting phases (Audio.startRunwayBeat)"], max_s=60, rms_db=-20),
]

for entry in CATALOG:
    entry.setdefault("loop", False)

# Config.Sounds keys that keep their current, working value (no file needed).
KEEP_BUILTIN = {
    "MinigameBoom": "rbxasset://sounds/impact_explosion_03.mp3",
    "MinigameSplash": "rbxasset://sounds/impact_water.mp3",
}
