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

Original addon by Aviana: https://github.com/Aviana/YaHT
