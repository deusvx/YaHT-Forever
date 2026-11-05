# YaHT Forever – Yet another Hunter Timer

An Auto Shot timer for **WoW Forever** hunters (game version 1.60.x, interface `16001`).
A port of Aviana's classic **YaHT**, rebuilt for Forever's modern client and tuned against real
in-game shot timings.

## Features
- **Accurate swing bar:** reload, then the red "stand still" wind-up, ending as the shot leaves.
  - Uses Forever's own swing data (`PLAYER_SWING`), with a wind-up that scales with ranged haste.
  - Learns your connection's small per-shot delay and smooths out network jitter.
  - Follows the game's 0.5s retry rhythm when you move, so it stays right while kiting.
- **Countdown:** seconds until the shot (or until you must stand still), to one decimal.
  - Snap it inside or outside the bar, above or below it, or drag it anywhere.
- **Glow:** builds up as the reload runs out, full while you must stand still.
  - Soft or Outline look, optional pulse and light sweep.
  - Uses WeakAuras' glow effects (LibCustomGlow) if you have it installed.
- **Sparks:** two sparks race out from the middle during the wind-up.
- **Ready pulse:** if you're moving when the shot is ready, lines pulse in the middle until you stop.
- **Ammo counter:** a movable icon that stays hidden while you have plenty, fades in as ammo
  runs down, and flashes yellow, then red, with a warning sound.
- **Tranquilizing Shot announce** to Say, Party, Raid, Raid Warning, Whisper or a channel.
- **Quick looks** (Minimal / Clean / Flashy), reset buttons on every tab, and profiles.
- Lightweight: hidden and idle when you're not shooting; well under 1% of a frame when you are.
- English, German, Simplified and Traditional Chinese.

## Install
1. Unzip so you end up with `World of Warcraft/_forever_/Interface/AddOns/YaHT/YaHT.toc`.
   The folder must be named exactly `YaHT`.
2. Restart the game and enable **YaHT Forever** in the AddOns list.
3. On first login the bar is unlocked (preview mode). Drag it where you want it, then type `/yaht lock`.

## Commands
| Command | What it does |
|---|---|
| `/yaht` | Options (also under Settings → AddOns and the addon button by the minimap) |
| `/yaht lock` / `/yaht unlock` | Lock the bar, or unlock it to move things and preview every effect |
| `/yaht reset` | Move the bar back to the middle of the screen |
| `/yaht ammo` | Show how much ammo YaHT counts |
| `/yaht debug` | Print shot timings after every Auto Shot |
| `/yaht copy` / `/yaht clear` | Copy the debug log (Ctrl+C), or empty it |
| `/yaht help` | List the commands |

## How the timing works on Forever
- `PLAYER_SWING` gives the exact swing time each shot. The wind-up is
  `0.5s × current speed ÷ weapon base speed`.
- Auto Shot keeps firing during Aimed Shot casts on Forever. If Blizzard changes that back, there's
  a **Casts hold Auto Shot** switch on the Timing tab.
- Shots are evenly spaced, but the message about each one arrives up to about 0.1s early or late.
  The bar keeps a steady rhythm instead of jumping with every message.
- If a shot attempt fails (you were moving), the game retries every 0.5s. After you stop, the
  wind-up starts at the next retry moment.
- Extra shot requests the game rejects while a wind-up is already running are ignored.
- Your per-shot delay is learned per character (one saved number). Timing tab → **Relearn timing**
  starts over.

## Notes
- Forever blocks addons from the combat log, so Tranquilizing Shot is announced on cast; a miss
  can't be detected.
- Say/Yell/Channel announcements from addons only work inside instances, and addon chat is paused
  during boss fights. YaHT skips those quietly.
- If the game says the addon is out of date, check your interface number with
  `/dump select(4, GetBuildInfo())` and put it on the `## Interface:` line of `YaHT.toc`.

## Credits & license
- Original YaHT by **Aviana**: https://github.com/Aviana/YaHT (public domain, see `LICENSE`).
- WoW Forever port by **Prime**.
- Timing research helped by WeaponSwingTimer-SixxFix's Forever branch.
- Bundled Ace3 libraries © Ace3 Development Team (see `libs/Ace3-LICENSE.txt`).
