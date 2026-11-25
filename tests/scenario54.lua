-- Sounds are choices (1.5.4). Wherever YaHT had a switch for a sound there is one list instead:
-- "No sound" or one of the game's sounds. Picking one plays it; YaHT's own window has "Hear it".
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end

-- a game that has all the sounds but one (the bell): that one is simply not offered
SOUNDKIT = {MAP_PING = 1, IG_QUEST_LIST_COMPLETE = 2, TELL_MESSAGE = 3, LOOT_WINDOW_COIN_SOUND = 4, IG_PLAYER_INVITE = 5,
  READY_CHECK = 7, ALARM_CLOCK_WARNING_3 = 8, RAID_WARNING = 9}
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db = YaHT.db.profile
local R = LibStub("AceConfigRegistry-3.0")
local opts = R:GetOptionsTable("YaHT")("dialog","AceConfigDialog-3.0")
R:ValidateOptionsTable(opts, "YaHT")
local function last() return sounds[#sounds] end

-- every sound setting has a choice kept beside it, with a default, and none is left as a bare switch
local n = 0
for key, kit in pairs(YaHT.soundKeys) do n = n + 1 assert(YaHT.defaults.profile[kit] ~= nil, "no default for the chosen sound "..kit) end
assert(n >= 20, "expected every sound to have a choice, found "..n)
local function walk(args, path)
  for key, opt in pairs(args) do
    if opt.type == "group" then walk(opt.args, path .. "/" .. key)
    elseif opt.type == "toggle" and key:find("sound") and not key:find("soundat") then
      error("a sound is still a bare switch: " .. path .. "/" .. key)
    end
  end
end
walk(opts.args, "")

-- the pet warning: on to start with, with the sound it always made
local pet = opts.args.alerts.args.petpage.args.petsound
assert(pet.type == "select" and pet.arg == "sound", "the pet sound should be a list of sounds")
assert(pet.get() == "WARNING", "what was on should show the sound it made before, shows "..tostring(pet.get()))
local v, order = pet.values(), pet.sorting()
assert(order[1] == "NONE" and v.NONE == "No sound" and v.PING and v.ALARM and v.WARNING, "the list should start with No sound and offer the sounds")
assert(v.BELL == nil, "a sound this game lacks should not be offered")
for _, id in ipairs(order) do assert(v[id], "the order names a sound that isn't offered: "..id) end
-- picking one plays it and keeps it
sounds = {}
pet.set(nil, "PING")
assert(db.petsound == true and db.petsoundkit == "PING" and #sounds == 1 and last() == 1, "picking a sound should play it and keep it")
assert(pet.get() == "PING", "the list should show what was picked")
-- No sound: silent, and nothing plays when you pick it
sounds = {}
pet.set(nil, "NONE")
assert(db.petsound == false and #sounds == 0 and pet.get() == "NONE", "No sound should switch it off quietly")
assert(db.petsoundkit == "PING", "the sound picked before should be remembered for when it is switched on again")
pet.set(nil, "CHIME") assert(db.petsound == true and last() == 2, "picking again should switch it back on")

-- a proc icon's pop-up sound: off to start with; the shared look and an icon's own look each have theirs
local procs = opts.args.alerts.args.procspage.args
assert(procs.procsound.type == "select" and procs.procsound.get() == "NONE", "the pop-up sound is off to start with")
procs.procsound.set(nil, "COINS")
assert(db.procsound == true and db.procsoundkit == "COINS", "the shared pop-up sound wasn't kept")
local mong = procs.mongoosepage.args
assert(mong.mongooseiconsound.type == "select", "an icon's own pop-up sound should be a list too")
db.mongooseown = true
mong.mongooseiconsound.set(nil, "INVITE")
assert(db.mongooseiconsound == true and db.mongooseiconsoundkit == "INVITE", "an icon's own pop-up sound wasn't kept")
-- "sound at seconds left": its own list, right under the seconds, only once a time is set
local at, kit = mong.mongoosesoundat, mong.mongoosesoundatkit
assert(at and kit and kit.type == "select" and kit.order > at.order and kit.order < at.order + 0.1, "the seconds-left sound should sit right under the seconds")
assert(kit.disabled() == true, "no sound to choose while no time is set")
db.mongoosesoundat = 3 assert(kit.disabled() == false, "with a time set the sound can be chosen")
assert(kit.get() == "ALARM" and kit.values().NONE == nil, "it starts as the alarm, and has no No sound entry (0 seconds means never)")
sounds = {} kit.set(nil, "READY") assert(db.mongoosesoundatkit == "READY" and last() == 7, "picking the seconds-left sound should play and keep it")
-- the hawks have both as well
local hawk = opts.args.alerts.args.hawkpage.args
assert(hawk.hawksoundatkit and hawk.hawkiconsound.type == "select", "the hawks should have their sound choices")
-- the ammo counter has two: running low, and nearly out
local ammo = opts.args.alerts.args.ammopage.args
assert(ammo.ammosound.type == "select" and ammo.ammocritkit and ammo.ammocritkit.get() == "WARNING" and ammo.ammosound.get() == "ALARM", "the ammo counter should have a choice for each of its two sounds")

-- a sound this game lacks falls back to what that warning always sounded like
sounds = {} YaHT:PlayChoice(db.procsoundkit, "PING") assert(last() == 4, "the chosen sound isn't what plays")
sounds = {} YaHT:PlayChoice("BELL", "ALARM") assert(last() == 8, "a missing sound should fall back to the usual one")
sounds = {} YaHT:PlayChoice(nil, "WARNING") assert(last() == 9, "no choice kept yet should mean the usual sound")

-- Reset this page puts the chosen sounds back too
db.petsoundkit = "COINS" db.petsound = false
opts.args.alerts.args.petpage.args.reset.func()
assert(db.petsound == true and db.petsoundkit == "WARNING", "Reset should put the pet sound back")

-- YaHT's own window: a "Hear it" button beside a list of sounds plays the one that is picked
SlashCmdList["YAHT"]("")
local M = YaHT.menu
local function row(key) for _, r in ipairs(M.rows) do local p = r.item and r.item.path if p and p[#p].key == key then return r end end end
M.Show("alerts/petpage")
local r = row("petsound")
assert(r and r.kind == "select" and r.hear and r.hear.shown, "no Hear it button beside the pet sound")
sounds = {} r.hear.scripts.OnClick(r.hear)
assert(#sounds == 1 and last() == 9, "Hear it should play the sound that is picked")
assert(row("petwhen") and not row("petwhen").hear.shown, "a list that isn't a sound must not get the button")
-- nothing to hear for "No sound"
pet.set(nil, "NONE") M.Render()
assert(row("petsound") and not row("petsound").hear.shown, "No sound: no Hear it button")
-- picking from the list in the window plays it, and the button is back
sounds = {} row("petsound").onPick("PING")
assert(db.petsoundkit == "PING" and sounds[1] == 1 and row("petsound").hear.shown, "picking in the window should play the sound and bring the button back")
print("OK54")
