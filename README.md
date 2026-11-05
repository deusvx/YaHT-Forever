# YaHT – WoW Forever port
Yet another Hunter Timer (auto shot timer), ported to the **WoW Forever** client (game version 1.60.1, TOC interface `16001`).

## Install
1. Unzip so you end up with `World of Warcraft/_forever_/Interface/AddOns/YaHT/YaHT.toc`
   (the folder must be named exactly `YaHT`, not `YaHT-main` / `YaHT-wow-forever`).
2. Restart the game, enable YaHT in the AddOns list on the character screen.
3. `/yaht` opens the options. Unlock the bar to drag it, lock it to use it.

If the game says the addon is "out of date", check your interface number in-game with
`/dump select(4, GetBuildInfo())` and put that number on the `## Interface:` line of `YaHT.toc`.

## What changed vs. the original Classic version
- Ace3 libraries are bundled (the original repo only had them in release zips).
- LibSharedMedia is optional; built-in bar/background/border textures are used if it's absent.
- Spell names use `C_Spell.GetSpellName` when available (old `GetSpellInfo` as fallback).
- Aimed Shot / Multi-Shot detection uses `UNIT_SPELLCAST_*` events instead of the combat log.
- The old hack that rewrote Blizzard's cast bar was removed (those internal functions no
  longer exist on the modern client; the default cast bar already shows real cast times).
- Tranquilizing Shot announce: uses the combat log if the client allows it (hit + miss);
  otherwise announces on cast. Say/Yell may be blocked by the game outside instances.
- Every event is registered defensively so a missing/forbidden event can't break the addon.

## Auto Shot timing on WoW Forever
Based on research and on the Forever build of WeaponSwingTimer-SixxFix
(github.com/watchyoursixx/WeaponSwingTimer-SixxFix, `forever` branch):
- The game sends a native `PLAYER_SWING` event with the exact ranged swing time every shot.
  YaHT uses it as the shot signal, falling back to spell-cast events if a client lacks it.
- **Wind-up** (stand-still part) = 0.5 s × current ranged speed ÷ weapon base speed, so haste
  shortens it. You can set a fixed value instead under `/yaht` → Timing.
- **Aimed Shot no longer pauses the timer.** Auto Shot keeps firing during casts on Forever.
  Turn on "Casts hold Auto Shot" if that changes back.
- Forever blocks addons from the combat log and can hide stats ("secret values") in combat.
  YaHT checks for both, and keeps the last known value when a stat is hidden.
- `/yaht debug` prints swing time, base speed, wind-up and cooldown after every shot.

## Countdown text
Shows the time left to one decimal place (like WeaponSwingTimer), counting down to the shot
or, optionally, to when you must stand still. Under `/yaht` → Countdown text: snap it inside the
bar (left/center/right), outside (left/right), above or below, fine-tune with X/Y offsets,
or unlock the bar and drag the number where you want it. Font, size and color are adjustable.

## Glow
Optional glow around the bar: nothing while the bar is full, building up as the reload runs
out, full (optionally pulsing) when you need to stand still. Under `/yaht` → Glow pick color,
size, brightness and style. If WeakAuras (or another addon that includes LibCustomGlow) is
installed, the stand-still part can use its animated effects: Pixel, Autocast, Proc or Button.
Built in: Soft or Outline glow look, and a Sweep effect (a light streak runs across the bar).

## Spark
A bright line at the moving edge of the bar. In the stand-still part the bar grows out from the
middle, so two sparks start at the centre and race to the ends as the shot fires. Choose Off,
Stand-still part only, or Always; set height and color under `/yaht` → Spark.

Original addon by Aviana: https://github.com/Aviana/YaHT
