# Changelog

## 1.5.2
- New: a tracking wheel. A small button shows what you are tracking. Click it and everything you
  can track opens around it as a pie, one piece each: move the mouse into the piece you want (the
  whole piece lights up) and on out of the pie, and you track it. A click on the one you track switches tracking off, and a click in
  the middle closes the wheel. Drag the button anywhere while the bar is unlocked. Its own page
  (Tools, "Tracking wheel"): choose by moving out of the pie or by clicking, size, and whether
  the minimap's other filters join the wheel. The button sits behind your bags and other windows.
- The deadzone and too-far warnings are gone the moment you are out of them, instead of fading away
  over half a second.
- Options: a gold dot marks every setting you changed from its default. Right-click a setting to put
  just that one back.
- Options: a "My changes" button next to the search box lists every setting that is off its default
  in one place, and shows how many there are. Next to it, "Back" takes you to the page before.
- Options: share your setup. The Profiles page shows it as one line of text to copy, and takes one
  that someone sent you (with an undo). The places things sit on your screen are not part of it.
- Options: in the list on the left the alerts are three sections of their own (Warnings, Timers
  and icons, Tools) instead of one long "Alerts" list. Tranquilizing Shot announce moved from
  Advanced to Tools.
- Options: the window opens on the page you left, also after a reload.
- Options: Ctrl + mouse wheel moves a slider one step (the wheel alone still scrolls the page), and
  switches, lists and buttons click like the game's own.
- After an update, a line in chat says so and the options' Home page shows what is new, once.
  /yaht new shows it again.

## 1.5.1
- New: a Raptor Strike icon. While Raptor Strike is queued for your next melee swing, its icon shows
  next to the bar (like the lit-up button on your action bar), with a timer that runs down to the
  swing. Its own page under Procs, with the same options as the other icons.
- New: Lone Wolf look, for hunters who play without a pet. While no pet is out, the bar turns
  moonlight silver and becomes a marksman's scope: a range scale under the bar, and a crosshair
  that locks on in the middle the moment you have to stand still. Pet warnings go quiet and
  Bestial Wrath's place is freed. With a pet out, everything is regular. Automatic with the Lone
  Wolf talent, or switch it on yourself (The bar, "Lone Wolf" tab). With the talent, "PET OUT" warns
  you in a fight when a pet is out and costing you the bonus. Colors, crosshair size and the
  warning each have their own setting.
- Fixed: "NO PET" kept showing for hunters who play without a pet (Lone Wolf builds). It now stays
  quiet with Lone Wolf, and for anyone after three fights in a row without a pet. It comes back by
  itself the next time you have a pet out.

## 1.5.0
- New: a Bestial Wrath icon. It shows for its 18 seconds from the moment you cast it, then stays grey
  with a countdown until you can cast it again (both can be switched off). It has the prime spot:
  first in the row, so above the bar it stands centered and the other icons line up to its right.
  That place is only kept for hunters who have Bestial Wrath; for everyone else nothing moves.
- New: Multi-Shot's cast. Multi-Shot does not leave right away, and the game shows no cast bar for
  it. A thin line under the bar now fills while it casts, so you see the moment it goes out. It
  times your real casts and adjusts itself. Its own page (Alerts, "Multi-Shot cast"): under or over
  the bar, thickness, width, color, opacity, and a Test button.
- New: the deadzone and too-far warnings as text ("DEADZONE" / "TOO FAR"), under the bar, over it,
  or anywhere you drag it, with your own wording, size and color. Each warning has one "Show as"
  choice: off, stripes or arrows, text, or both.
- New: the distance to your target, as a band of yards ("20-28 yd"), green when you can shoot. As a
  number, a ruler of the zones, or both. The game gives addons no exact distance, so it is the
  narrowest band its range checks allow. (Alerts, Range, "Distance"; off to start with.)
- New: Pack or Cheetah on in a fight gets your attention, until you switch aspect. Each has its own
  choice on the Aspect page: bouncing words ("Pack On!" / "Cheetah On!", movable), the icon itself
  bouncing and glowing, both, or nothing extra. Pack starts on words, Cheetah on the icon. Each time
  you take a hit in that state, the warning doubles in size and flashes for a moment.
- New: "Sound at seconds left" on every timed icon and the hawks. Set a number of seconds and a
  warning sound plays once when that much time is left (for example hawks at 6 seconds). 0 = never.
- New: "Show seconds left" on every proc icon: the time left as a number on the icon.
- Simpler option pages. Every icon's page has the same short layout in cards (Icon, Time, Fine
  tuning); the fine settings are under "More options", which starts closed. The Range, Aspect and
  Profiles pages are shorter, every card has a title, and no setting appears on two pages.
- A small gear beside every switch that has a page of its own: one click takes you to that feature's
  settings.
- The live preview shows more: icon sizes to scale, Multi-Shot's cast line on its page, and the
  deadzone and too-far warnings on the Range page, each as you have set it.
- Fixed: the bar could keep coming up each time you stopped moving, with no target and out of a
  fight (after a loading screen cut an Auto Shot run short). It now puts itself away.
- Feign Death resist alert: a check that was left open can no longer hold back the next alert.

## 1.4.0
- New: hawk icons for Summon Hawk. Each hawk that is out shows by the bar with its 18 seconds running
  down and the seconds left as a number. Under 6 seconds it turns red: Summon Hawk shares its cooldown
  with Arcane Shot, so red means summon again first. A third cast replaces the older hawk in its own
  place. Show one icon per hawk or one with a count, at the bar's top left or top right, in the row
  with the other icons, or anywhere you drag them. Settings are on a new Hawks page under Alerts;
  /yaht hawk shows what YaHT sees of your hawks.
- New: round or square icons. Shape is a setting of the proc icons (their shared look, or an icon's
  own), of the aspect badge and of the hawks. A round icon is the picture inside a ring that runs down
  as its timer; a square one has its timer line under it. Glows follow the shape. "Round icons" on the
  Home page switches every icon at once.
- New: a polished look. Bevelled frames and rings with fine edges, a soft light on the icon and a
  shadow under it. It is off to start with. "Polished look on every icon" on the Home page switches
  it for everything at once, and each icon's page has its own switch.
- The quick looks are now three presets you can look at before you use them: Minimal is just the
  bar, Clean is the bar with its icons, Flashy is everything with every effect. Click one to see it
  in the live preview, then "Use this look" to keep it; until then nothing changes. Each card
  shows the look on your own bar, with the icons where you placed them. Size, position, colors and
  the countdown are never touched.
- The options window: the main switches carry a small picture, in color while the switch is on, so
  you find them at a glance. The live preview is taller and now shows the hawks, round and polished
  icons, and icons you dragged anywhere on the screen (apart, in its corner). Icons above the bar
  stand in the preview as they do in the game.

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
