-- Marksmanship (1.5.7): Sniper Shot's cooldown on an icon, and a Trueshot Aura reminder that shows
-- only while the aura is NOT on. Both only for a hunter who has the spell.
local names = {[19506] = "Trueshot Aura", [999001] = "Sniper Shot", [3045] = "Rapid Fire"}
local oldName = C_Spell.GetSpellName
C_Spell.GetSpellName = function(id) return names[id] or oldName(id) end
C_Spell.GetSpellTexture = function(id) return "icon"..tostring(id) end
local book = {} -- spell name -> its number, for the spells this hunter has
C_Spell.GetSpellInfo = function(n) local id = book[n] if id then return {spellID = id, iconID = "book"..id, name = n} end end
IsPlayerSpell = function(id) for _, v in pairs(book) do if v == id then return true end end return false end
local cdS, cdD = 0, 0
C_Spell.GetSpellCooldown = function() return {startTime = cdS, duration = cdD} end
local buffs, fighting, dead = {}, false, false
C_UnitAuras = C_UnitAuras or {}
C_UnitAuras.GetAuraDataByIndex = function(unit, i) return buffs[i] end
InCombatLockdown = function() return fighting end
UnitIsDeadOrGhost = function() return dead end
UnitOnTaxi = function() return false end

local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db = YaHT.db.profile
local s, t, w, tw = YaHT.sniperFrame, YaHT.trueshotFrame, YaHT.castBuffWatch, YaHT.trueshotWatch
assert(s and t and w and tw, "no Sniper Shot icon or Trueshot Aura reminder")
assert(db.sniper == true and db.trueshot == true and db.sniperpos == "ABOVE" and db.trueshotpos == "ABOVE", "both should start out on, above the bar")

local dt = 0.05
local function run(sec) for k = 1, math.floor(sec/dt + 0.5) do advance(dt)
  for _, f in ipairs({w, tw, s, t}) do if f.shown then f.scripts.OnUpdate(f, dt) end end end end
local function tell(event, ...) tw.scripts.OnEvent(tw, event, ...) end
local function cast(id) w.scripts.OnEvent(w, "UNIT_SPELLCAST_SUCCEEDED", "player", "g", id) tell("UNIT_SPELLCAST_SUCCEEDED", "player", "g", id) end

-- A HUNTER WITHOUT THEM: nothing shows, not even while placing things, and no place is kept in the row
assert(YaHT.SniperKnown() == false and YaHT.TrueshotKnown() == false, "this hunter has neither yet")
db.afterallpos = "ABOVE" -- (a stand-in that comes after every icon in the row)
local hawkShift = YaHT.ProcSlotShift(db, "afterall")
assert(not s.shown and not t.shown, "nothing to place for a hunter without them")
db.lock = true YaHT:ApplySettings()
run(4) assert(not t.proc and not t.shown, "no Trueshot Aura reminder for a hunter who doesn't have it")

-- YOU LEARN THEM: the game says your spells changed
book["Sniper Shot"], book["Trueshot Aura"] = 999001, 19506
tell("SPELLS_CHANGED")
assert(YaHT.SniperKnown() and YaHT.TrueshotKnown(), "now in the spellbook")
assert(YaHT.ProcSlotShift(db, "afterall") > hawkShift, "their places in the row are kept now")

-- TRUESHOT AURA NOT ON: the reminder comes (after a moment, not at once), and stays
run(0.6) assert(not t.proc, "not at once: buffs can blink")
run(1.6) assert(t.proc and t.shown, "Trueshot Aura is missing: the reminder should show")
assert(not t.cdShade.shown and not t.cdText.shown, "in colour, no number on it")
run(30) assert(t.proc and t.shown, "it stays for as long as the aura is missing")

-- YOU PUT IT ON: gone
buffs = {{name = "Trueshot Aura", spellId = 19506}}
tell("UNIT_AURA", "player") run(0.3)
assert(not t.proc, "the aura is on: the reminder goes")
run(1) assert(not t.shown and not tw.shown, "gone, and the watcher asleep")
-- (found by its name too, for the ranks Forever added)
buffs = {{name = "Something", spellId = 5}, {name = "Trueshot Aura", spellId = 1234567}}
tell("UNIT_AURA", "player") run(2.5) assert(not t.proc, "a new rank is told by its name")

-- IN A FIGHT the game hides your buffs: what was seen before the fight stands
fighting = true buffs = {}
tell("PLAYER_REGEN_DISABLED") tell("UNIT_AURA", "player") run(3)
assert(not t.proc, "hidden buffs must not read as 'missing'")
-- the fight ends and it really is gone (you died, came back): the reminder
fighting = false dead = true
tell("PLAYER_REGEN_ENABLED") run(3) assert(not t.proc, "no reminder while you are dead")
dead = false tell("PLAYER_UNGHOST") run(2.2) assert(t.proc, "alive again without the aura: the reminder")
-- into a fight with the reminder up: it stays; your cast takes it away (the buff itself cannot be seen)
fighting = true tell("PLAYER_REGEN_DISABLED") run(2) assert(t.proc, "still missing in the fight: it stays")
cast(19506) run(0.3) assert(not t.proc, "your cast in a fight should take the reminder away")
fighting = false buffs = {{name = "Trueshot Aura", spellId = 19506}} tell("PLAYER_REGEN_ENABLED") run(2)
assert(not t.proc)

-- after a loading screen the buffs come a moment late: no reminder in that moment
buffs = {} tell("PLAYER_ENTERING_WORLD") run(2) assert(not t.proc, "just after a loading screen: wait")
buffs = {{name = "Trueshot Aura", spellId = 19506}} tell("UNIT_AURA", "player") run(3) assert(not t.proc)

-- switched off: nothing
buffs = {} tell("UNIT_AURA", "player") run(2.2) assert(t.proc)
db.trueshot = false YaHT:ApplySettings() run(1) assert(not t.proc and not t.shown, "switched off: no reminder")
db.trueshot = true YaHT:ApplySettings() run(2.5) assert(t.proc, "switched on again: it comes back by itself")
buffs = {{name = "Trueshot Aura", spellId = 19506}} tell("UNIT_AURA", "player") run(1)

-- SNIPER SHOT: fired -> its cooldown on the icon (the usual 15 seconds when the game hides the real one)
assert(not s.proc and not s.shown, "nothing until you fire it")
C_Spell.GetSpellCooldown = function() return SECRET end
cast(999001) run(0.1)
assert(s.proc and s.shown and s.afterUse and s.cdDur == 15, "fired: its 15 second cooldown should show")
assert(s.cdShade.shown and s.cdText.shown and s.cdText.txt == "15", "grey, with the seconds left: "..tostring(s.cdText.txt))
assert(s.icon.tex == "icon999001", "the spell's own picture")
run(7) assert(s.proc and s.cdText.txt == "8", "it counts down: "..tostring(s.cdText.txt))
run(8) assert(s.proc and not s.cdShade.shown, "cooldown over: in colour for a moment (ready)")
run(1.6) assert(not s.proc, "then it goes")
run(1) assert(not s.shown and not w.shown, "gone, and the watcher asleep")
-- the game says the real cooldown: that one is used (also when it says so a moment late)
C_Spell.GetSpellCooldown = function() return {startTime = cdS, duration = cdD} end
cdS, cdD = GetTime(), 13
cast(999001) run(0.1) assert(s.cdDur == 13 and s.cdText.txt == "13", "the game's own cooldown: "..tostring(s.cdText.txt))
run(15) assert(not s.proc)
cdS, cdD = 0, 0
cast(999001) run(0.1) assert(s.cdDur == 15)
cdS, cdD = GetTime() - 0.1, 12 run(0.5) assert(s.cdDur == 12, "the real cooldown, learned a moment after the cast")
run(14) assert(not s.proc)
cdS, cdD = 0, 0
-- another cast (Rapid Fire) is not Sniper Shot
cast(3045) run(0.1) assert(not s.proc, "only Sniper Shot starts it")
run(16)
-- switched off: nothing
db.sniper = false YaHT:ApplySettings() cast(999001) run(0.2) assert(not s.proc and not s.shown, "switched off")
db.sniper = true YaHT:ApplySettings()

-- "Preview all alerts" shows both
YaHT:PreviewAlerts() run(0.3)
assert(s.proc and t.proc, "both should be in the preview")
run(7) assert(not s.proc and not t.proc, "and leave after it (the aura is on)")

-- the settings: a switch and a page each, marked New; no "Time" card (they have no time to set)
local procs = YaHT.optionsTable.args.alerts.args.procspage.args
assert(procs.sniper and procs.trueshot and procs.sniperpage and procs.trueshotpage, "no settings for them")
assert(procs.sniper.hidden() == false and procs.trueshot.hidden() == false, "their switches are listed for a hunter who has them")
book = {} tell("SPELLS_CHANGED") tell("PLAYER_TALENT_UPDATE")
assert(procs.sniper.hidden() == true and procs.trueshot.hidden() == true, "and not for one who has not (after a respec)")
assert(not s.shown and not t.shown, "nothing left on screen after the respec")
book["Sniper Shot"], book["Trueshot Aura"] = 999001, 19506 tell("SPELLS_CHANGED")
for _, key in ipairs({"sniper", "trueshot"}) do
  local a = procs[key.."page"].args
  assert(a[key] and a[key.."pos"] and a[key.."size"] and a[key.."shape"], key..": the same basics as every icon")
  assert(a[key.."numbers"].hidden == true and a[key.."soundat"].hidden == true and a[key.."cardtime"].hidden == true, key..": no Time card")
  assert(YaHT:IsNew("key", key) and YaHT:IsNew("page", "alerts/procspage/"..key.."page"), key..": made new, so marked New")
end
assert((YaHT.errorCount or 0) == 0, tostring(YaHT.lastError))
print("OK64")
