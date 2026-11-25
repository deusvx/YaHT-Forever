-- Sounds are choices (1.5.4). Wherever YaHT had a switch for a sound there is one list instead:
-- "No sound" or one of the game's sounds. Picking one plays it; YaHT's own window has "Hear it".
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end

-- a game that lacks one of the game's sounds (the ping): that one is simply not offered. YaHT's own
-- sounds are files; the game says whether it could play one.
SOUNDKIT = {ALARM_CLOCK_WARNING_3 = 8, RAID_WARNING = 9}
local canPlayFiles = true
function PlaySoundFile(path, channel)
  if not canPlayFiles then return nil end
  assert(channel == "Master", "sounds should play on the Master channel")
  sounds[#sounds + 1] = path:match("Sound%-(%a+)%.ogg") or path
  return true, 1
end
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
assert(order[1] == "NONE" and v.NONE == "No sound" and v.ALARM and v.WARNING, "the list should start with No sound and offer the sounds")
assert(order[2] == "PUMP" and v.PUMP == "Shotgun pump" and v.BOW and v.HORN and v.DRUM and v.BLADE and v.BOLT and v.THUD, "YaHT's own hunter sounds should come first")
assert(v.PING == nil, "a sound this game lacks should not be offered")
for _, id in ipairs(order) do assert(v[id], "the order names a sound that isn't offered: "..id) end
-- picking one plays it and keeps it
sounds = {}
pet.set(nil, "PUMP")
assert(db.petsound == true and db.petsoundkit == "PUMP" and #sounds == 1 and last() == "Pump", "picking a sound should play it and keep it")
assert(pet.get() == "PUMP", "the list should show what was picked")
-- No sound: silent, and nothing plays when you pick it
sounds = {}
pet.set(nil, "NONE")
assert(db.petsound == false and #sounds == 0 and pet.get() == "NONE", "No sound should switch it off quietly")
assert(db.petsoundkit == "PUMP", "the sound picked before should be remembered for when it is switched on again")
pet.set(nil, "BOLT") assert(db.petsound == true and last() == "Bolt", "picking again should switch it back on")

-- a proc icon's pop-up sound: off to start with; the shared look and an icon's own look each have theirs
local procs = opts.args.alerts.args.procspage.args
assert(procs.procsound.type == "select" and procs.procsound.get() == "NONE", "the pop-up sound is off to start with")
procs.procsound.set(nil, "BOW")
assert(db.procsound == true and db.procsoundkit == "BOW", "the shared pop-up sound wasn't kept")
local mong = procs.mongoosepage.args
assert(mong.mongooseiconsound.type == "select", "an icon's own pop-up sound should be a list too")
db.mongooseown = true
mong.mongooseiconsound.set(nil, "BLADE")
assert(db.mongooseiconsound == true and db.mongooseiconsoundkit == "BLADE", "an icon's own pop-up sound wasn't kept")
-- "sound at seconds left": its own list, right under the seconds, only once a time is set
local at, kit = mong.mongoosesoundat, mong.mongoosesoundatkit
assert(at and kit and kit.type == "select" and kit.order > at.order and kit.order < at.order + 0.1, "the seconds-left sound should sit right under the seconds")
assert(kit.disabled() == true, "no sound to choose while no time is set")
db.mongoosesoundat = 3 assert(kit.disabled() == false, "with a time set the sound can be chosen")
assert(kit.get() == "ALARM" and kit.values().NONE == nil, "it starts as the alarm, and has no No sound entry (0 seconds means never)")
sounds = {} kit.set(nil, "HORN") assert(db.mongoosesoundatkit == "HORN" and last() == "Horn", "picking the seconds-left sound should play and keep it")
-- the hawks have both as well
local hawk = opts.args.alerts.args.hawkpage.args
assert(hawk.hawksoundatkit and hawk.hawkiconsound.type == "select", "the hawks should have their sound choices")
-- the ammo counter has two: running low, and nearly out
local ammo = opts.args.alerts.args.ammopage.args
assert(ammo.ammosound.type == "select" and ammo.ammocritkit and ammo.ammocritkit.get() == "WARNING" and ammo.ammosound.get() == "ALARM", "the ammo counter should have a choice for each of its two sounds")

-- what plays is what was picked; anything that can't be played falls back to what that warning always sounded like
sounds = {} YaHT:PlayChoice(db.procsoundkit, "PING") assert(last() == "Bow", "the chosen sound isn't what plays")
sounds = {} YaHT:PlayChoice("ALARM", "WARNING") assert(last() == 8, "one of the game's sounds should play as before")
sounds = {} YaHT:PlayChoice("PING", "ALARM") assert(last() == 8, "a sound this game lacks should fall back to the usual one")
sounds = {} YaHT:PlayChoice("COINS", "WARNING") assert(last() == 9, "a choice from an older version should fall back to the usual sound")
sounds = {} YaHT:PlayChoice(nil, "WARNING") assert(last() == 9, "no choice kept yet should mean the usual sound")
-- a file the game hasn't loaded (the addon was updated while the game ran): the usual sound, not silence
canPlayFiles = false
sounds = {} YaHT:PlayChoice("PUMP", "ALARM") assert(#sounds == 1 and last() == 8, "a file that won't play should fall back to the usual sound")
canPlayFiles = true
-- every hunter sound has its file in the addon
for _, id in ipairs(YaHT.SOUND_ORDER) do
  assert(YaHT.SOUND_NAME[id], "a sound without a name: "..id)
  sounds = {} YaHT:PlayChoice(id, "WARNING")
  if type(last()) == "string" then
    local fh = io.open("../media/Sound-" .. last() .. ".ogg", "rb")
    assert(fh, "the file for " .. id .. " is not in media")
    assert(fh:read(4) == "OggS", "not an ogg file: " .. id) fh:close()
  end
end

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
pet.set(nil, "DRUM") M.Render()
sounds = {} row("petsound").hear.scripts.OnClick(row("petsound").hear)
assert(#sounds == 1 and last() == "Drum", "Hear it should play a hunter sound that is picked")
assert(row("petwhen") and not row("petwhen").hear.shown, "a list that isn't a sound must not get the button")
-- nothing to hear for "No sound"
pet.set(nil, "NONE") M.Render()
assert(row("petsound") and not row("petsound").hear.shown, "No sound: no Hear it button")
-- picking from the list in the window plays it, and the button is back
sounds = {} row("petsound").onPick("THUD")
assert(db.petsoundkit == "THUD" and sounds[1] == "Thud" and row("petsound").hear.shown, "picking in the window should play the sound and bring the button back")
print("OK54")
