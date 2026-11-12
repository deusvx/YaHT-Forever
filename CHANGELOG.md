# Changelog

## 1.3.0
- New: YaHT's own options window (/yaht). The pages are listed on the left and the settings are
  grouped in boxes. On the right, a live preview shows your bar and icons as you change them, and a
  help panel explains the setting under your mouse. A Home page has the quick looks as live cards
  and the main switches, and a search box finds any setting. It is drawn smaller on small screens.
  Every setting, reset button and profile works as before; /yaht classic opens the old window.
- New: pet alerts. Small warning text you can drag anywhere on your screen (unlock the bar to move
  it): PET DEAD or NO PET when your pet is dead or missing in a fight (with a warning sound), PET NOT
  ATTACKING when you've been shooting for 3 seconds and your pet attacks nothing, and PET LOW when
  its health drops below a share you choose (35% by default). Forever hides your pet's exact health
  from addons, so PET LOW is drawn by the game itself and can't play a sound. Its own Pet page in
  the options: each warning on or off, the low threshold, text size, pulse and sound.
- Feign Death: a resist is now also noticed from your target's threat list (you stay on it). When
  the game shows no "Resisted" message the alert comes in a little over a second instead of 2.5,
  and it also catches resists where your pet pulls the mob off you.
- Feign Death: the RESIST alert shows at once when the game's "Resisted" message arrives a moment
  before the cast is confirmed (it could be 2.5 seconds late).
- Aspect badge: having no aspect is now also flagged out of a fight (yellow), while you shoot or
  when the badge is set to show always; it stays red in a fight. A blink without an aspect while you
  switch from one to another no longer warns.
- Proc icons can each have their own look (size, opacity, glow, pulse, sound) instead of the shared
  one: "Its own look" on each proc's page.
- The bar can be placed exactly: X and Y under The bar (slider, single-step arrows, or type the
  number), and a Grid switch at the top of the options (or /yaht grid) draws an alignment grid over
  the screen. Lock bar sits at the top of the options too.
- Sliders in the options have small arrows for single steps, and you can double-click the number to
  type a value.
- New: a minimap button. Left-click opens the options, right-click a quick menu (lock or unlock
  the bar, preview all alerts, options, hide the button), drag it around the minimap. Switch it
  off in the options or with /yaht minimap.
- New: /yaht selftest checks in the game that everything YaHT needs is there, that every options
  page draws and that every alert shows, and saves a report with your settings.
- New: a small always-on record of the things that are hard to test on purpose (pet warnings, aspect
  warnings, anything of YaHT's that broke); /yaht record shows the newest lines.
- Debug log: choose where its lines show (the main chat, another chat tab, or only the log) and
  switch it on or off under Advanced; the switch is remembered.
- Fixed: Mongoose Bite dropped out of "Preview all alerts" after a moment.

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
