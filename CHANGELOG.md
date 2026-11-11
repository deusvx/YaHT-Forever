# Changelog

## 1.2.0
- Timing: shots right after your attack speed changes (Rapid Fire, Quick Shots or another haste
  effect starting or ending) no longer teach the learned shot delay, so it stays accurate.
- Options: rebuilt for a cleaner menu. Sections are listed on the left in three groups (The bar,
  Alerts, Advanced), proc icons share one look, wording is clearer and consistent, and a "Preview all
  alerts" button shows every alert at once.
- New: range warnings. While you fight, yellow caution stripes show in the deadzone (on the line
  under the bar, or over the Auto Shot bar itself), and red arrows slide in from both ends when
  you're too far away. In normal shooting range nothing shows. Shown in combat only, or always
  with an enemy targeted. Its own Range tab sets this, where the deadzone shows, colors, stripe
  thickness, arrow size, opacity, extra brightness, animation speed and an optional (pulsing)
  deadzone glow.
- New: Feign Death resist alert. A separate, movable alert (the Feign Death icon with RESIST under
  it, plus a warning sound) when a mob resists your Feign Death. Test it from its options page.
- New: aspect badge. The icon of the aspect you're in sits next to the bar; it turns red and pulses
  for Cheetah or Pack in a fight (daze risk) or no aspect at all, with an optional yellow hint for
  Hawk in melee or Monkey at range. Its own Aspect section in the options.
- Every proc icon and the aspect badge can also be placed anywhere: set its Position to "Anywhere"
  and drag it while the bar is unlocked.
- New: Rapid Fire and racial ability alerts: their icons show while they last, from the moment you
  use them, next to the Quick Shots icon. The racial alert recognises the active of every Hunter race by itself
  (Elune's Light, Blood Fury, Berserking, Stoneform and more) and learns new ones' lengths.
- New: Quick Shots alert (Deadly Aspects talent): its icon shows while the 30% faster ranged
  attacks last. Forever hides your buffs from addons in combat, so YaHT notices it from your shot
  speed (Rapid Fire and Berserking are told apart) and uses the buff itself when the game shows it. Same glow, pulse and placement options as the
  Mongoose Bite alert; both now live in the new Procs section of the options.
- New: Mongoose Bite alert. After you dodge, the Mongoose Bite icon pops in next to the bar
  (above, left or right) with a gold timer that drains while you can use it. Pick a glow (halo, ring,
  shine, sparks, or proc/button glows with WeakAuras) and a pulse (breathe, grow, heartbeat, flash).
  Optional sound. If Mongoose Bite is still on cooldown, the icon shows it (grey, clock sweep and
  countdown) and pops back in color the moment you can press it.

## 1.1.0
- New: melee swing line. A hair-thin line under the Auto Shot bar that fills with your melee swing.
  It fades in only while you're hitting things in melee, turns gold while Raptor Strike is queued
  for your next swing, and a small glint runs along it on every swing. New Melee tab: on/off,
  only while meleeing or the whole fight, thickness, alpha, colors, glint, Raptor highlight.

## 1.0.1
- Spamming a key that includes Auto Shot (e.g. an Aimed Shot + Auto Shot macro) no longer makes
  the red stand-still part start early. The game refuses those presses while you reload, and
  YaHT now ignores the refusals instead of treating them as a new wind-up.
- On Forever an Aimed Shot cast pushes the next Auto Shot back a little. Those shots no longer
  count toward the learned delay, so the bar doesn't drift late after you use Aimed Shot.
- The red stand-still part now rolls smoothly while you spam keys: new timing info only speeds
  it up or slows it down, it no longer jumps back to empty and starts over.
- When the game's real wind-up starts a little after the bar expected it, the bar now follows it
  instead of ignoring it (it used to finish up to ~0.15s before the shot).
- Debug log (`/yaht debug`) now shows when an Aimed Shot / Multi-Shot cast starts and ends.

## 1.0.0 – first WoW Forever release
Ported from Aviana's YaHT (Classic) to the WoW Forever client.

**Timing**
- Uses Forever's `PLAYER_SWING` for exact swing times, and scales the 0.5s wind-up with ranged haste.
- Learns your per-shot network delay (saved per character) and smooths out message jitter.
- Follows the game's 0.5s retry rhythm when movement makes a shot attempt fail, so the bar stays
  right while kiting.
- Ignores extra shot requests the game rejects during a wind-up, and syncs the first shot of each
  Auto Shot run to the game's start signal.
- Resets on Feign Death.
- Aimed Shot no longer pauses the timer (Forever behaviour); a switch brings the Classic behaviour back.

**New features**
- Countdown text to one decimal, snapped to 7 positions or dragged anywhere.
- Glow that builds up through the reload: Soft or Outline look, pulse, light sweep, and WeakAuras
  (LibCustomGlow) effects.
- Sparks from the middle during the wind-up, and a ready pulse while you're moving.
- Ammo counter that fades in as ammo runs low and flashes yellow, then red, with a warning sound.
- Tabbed options with Quick looks, per-tab reset buttons, an Addon Compartment entry and slash commands.
- Debug log you can copy out of the game (`/yaht debug`, `/yaht copy`).

**Modern client**
- Safe with Forever's hidden combat values ("secret values") and its chat restrictions.
- No combat-log dependency; Tranquilizing Shot is announced on cast.
- Bundled Ace3; LibSharedMedia optional.
- English, German, Simplified and Traditional Chinese.
