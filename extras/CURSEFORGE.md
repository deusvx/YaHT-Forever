# YaHT Forever – Auto Shot timer for WoW Forever hunters

**Know exactly when to stop moving.** YaHT Forever is a lightweight Auto Shot bar built for WoW
Forever's client, tuned against real in-game shot timings, including while kiting.

A port of Aviana's classic **YaHT** (Yet another Hunter Timer).

## Why it's accurate on Forever
- **Uses the game's own swing data:** Forever's `PLAYER_SWING`, plus a wind-up that scales with
  your ranged haste.
- **Learns your connection:** it works out the small extra delay between your shots and remembers it.
- **Smooths network jitter:** shots are evenly spaced, but the game's messages aren't. The bar keeps
  a steady rhythm instead of twitching.
- **Kiting-aware:** when moving makes a shot fail, Forever retries every 0.5s. YaHT follows that
  rhythm, so after you stop the red part ends exactly as the arrow leaves.

## Features
- **Swing bar:** reload, then the red "stand still" wind-up.
- **Countdown:** time to the shot (or to when you must stand still), to one decimal. Snap it to 7
  positions or drag it anywhere.
- **Glow:** builds up as the reload runs out, full while you must stand still. Soft or Outline look,
  optional pulse and light sweep. Uses **WeakAuras glow effects** (Pixel, Autocast, Proc, Button)
  if you have WeakAuras installed.
- **Sparks:** two sparks race out from the middle of the bar during the wind-up.
- **Ready pulse:** moving with the shot ready? Lines pulse in the middle until you stop.
- **Ammo counter:** a movable icon that's invisible while you have plenty, fades in as you run low,
  and flashes yellow, then red, with a warning sound.
- **Melee swing line:** a hair-thin line under the bar that fills with your melee swing, only while
  you're in melee. Turns gold while Raptor Strike is queued, with a small glint on every swing.
- **Tranquilizing Shot announce** to Say, Party, Raid, Raid Warning, Whisper or a channel.
- **Quick looks:** Minimal, Clean or Flashy in one click. Reset buttons on every tab, plus profiles.

## Lightweight
- Hidden and doing nothing when you're not shooting.
- Well under 1% of a frame when you are, with no memory build-up.
- Shares its Ace3 libraries with your other addons.

## Getting started
1. Install, log in. The bar starts unlocked so you can place it.
2. Drag it where you want it, then type **/yaht lock**.
3. **/yaht** opens the options. It's also under Settings → AddOns and the addon button by the minimap.

| Command | |
|---|---|
| `/yaht lock` / `unlock` | Lock, or unlock to move and preview every effect |
| `/yaht reset` | Put the bar back in the middle |
| `/yaht ammo` | Show the ammo count YaHT sees |
| `/yaht debug` / `copy` | Log shot timings and copy them (great for bug reports) |

## Notes
- WoW Forever only (interface 16001).
- Forever blocks addons from reading the combat log, so Tranquilizing Shot is announced when you
  cast it; a miss can't be detected.
- Say/Yell announcements from addons only work inside instances, and addon chat is paused during
  boss fights. That's a game rule.
- Languages: English, German, Simplified and Traditional Chinese. Translation fixes are welcome!

**Bug reports:** turn on `/yaht debug`, play until it happens, then `/yaht copy` and paste the log
in a comment.

*Original YaHT by Aviana (public domain). WoW Forever port by Prime.*
