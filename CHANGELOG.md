# Changelog

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
