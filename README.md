# MixPlay — Automated Match Plugin for Counter-Strike 1.6 (AMX Mod X)

**Make matches start automatically when enough players join.**  
Designed for reHLDS servers and compiled with **AMX Mod X Dev 1.9.0** builds.

---

## 🔧 What this plugin does (overview)
- Waits for a minimum number of players (configurable via `amx_minplayer`) — until then the server runs deathmatch.
- Automatically selects two random captains for a knife round.
- Knife winner picks side and chooses the first player for their team.
- Match format: best-of-30 rounds (first to 16 wins). First half = 15 rounds, teams swap sides after 15 rounds.
- Teams are labeled **Team A** and **Team B** for consistent display.
- Chat & admin commands: `/rtv` (vote to restart map), `/rr` (admin round restart), `/score`, `/swap`, `/rates`.
- End-of-match stats and map voting for the next map.
- Robust error handling (captain disconnects, auto replacement, etc.).
- Round-by-round scoreboards, sound beeps, and clean UI messages.

---

## 🗂️ Repository contents
```
mixplay-plugin/
├─ src/
│  ├─ mixplay.sma        # main plugin 
│  └─ mixneeds.sma       # helper 
├─ configs/
│  ├─ clan.cfg          
│  ├─ pub.cfg            
│  ├─ knife.cfg         
│  ├─ server.cfg        
│  └─ game.cfg           
├─ build/                # compiled .amxx 
├─ README.md
├─ LICENSE
└─ .gitignore
```

---

## ✅ Quick start — install on a reHLDS server
1. Compile plugin using **AMX Mod X Dev 1.9.0** build tools.
2. Copy `mixplay.amxx and mixneeds.amxx` into `addons/amxmodx/plugins/`.
3. Copy configs into `/cstrike folder of server.
4. Edit `server.cfg` to include cvars (examples below).
5. Restart the server.

---

## ⚙️ cvars
```cfg
amx_minplayers "10"
amx_prefix "L2KMix"
```

---

## 🛠️ Commands
- `/rtv` — vote to restart the map
- `/rr` — admin round restart
- `/score` — show current score
- `/swap` — request swap in first round
- `/rates` — show recommended client rates

---

---

## 📝 License
MIT License

---
Made with ❤️ by B@IL
