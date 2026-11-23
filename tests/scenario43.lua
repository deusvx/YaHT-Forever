-- Bestial Wrath (1.5): an icon for its 18 seconds from your cast, in the prime spot (first in the row, so
-- above the bar it stands centred). The spot is only kept for a hunter who has Bestial Wrath.
local names = {[19574] = "Bestial Wrath", [3045] = "Rapid Fire", [1495] = "Mongoose Bite"}
local oldName = C_Spell.GetSpellName
C_Spell.GetSpellName = function(id) return names[id] or oldName(id) end
C_Spell.GetSpellTexture = function(id) return "icon"..tostring(id) end
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db = YaHT.db.profile
local b, m, w = YaHT.bestialFrame, YaHT.mongooseFrame, YaHT.castBuffWatch
assert(b and m and w, "no Bestial Wrath icon")
assert(db.bestial == true and db.bestialpos == "ABOVE" and db.mongoosepos == "ABOVE", "it should start out switched on, above the bar")

-- a hunter without Bestial Wrath: nothing shows (even while placing things) and nothing moves
assert(YaHT.BestialKnown() == false, "this hunter shouldn't count as having it yet")
assert(not b.shown and YaHT.ProcSlotShift(db, "mongoose") == 0 and m.point[4] == 0, "without Bestial Wrath its place must not be kept free")

local dt = 0.05
local function run(sec) for k = 1, math.floor(sec/dt + 0.5) do advance(dt)
  if w.shown then w.scripts.OnUpdate(w, dt) end
  if b.shown then b.scripts.OnUpdate(b, dt) end end end
local function cast(id) w.scripts.OnEvent(w, "UNIT_SPELLCAST_SUCCEEDED", "player", "g", id) end
db.lock = true YaHT:ApplySettings()
-- (its two options, seconds left and cooldown, are on to start with; the first checks run without the cooldown)
assert(db.bestialnumbers == true and db.bestialcooldown == true, "seconds left and cooldown should be on to start with")
db.bestialcooldown = false

-- you cast it: the icon runs for 18 seconds, and from now on it has the prime spot
local t0 = GetTime()
cast(19574) run(0.3)
assert(YaHT.db.char.bestialSeen == true and YaHT.BestialKnown(), "a cast should mark the hunter as having it")
assert(b.proc and b.shown and math.abs(b.procStart - t0) < 0.06 and b.window == 18, "Bestial Wrath not shown from the cast for 18s")
assert(b.icon.tex == "icon19574", "not its own icon: "..tostring(b.icon.tex))
assert(b.point[1] == "BOTTOM" and b.point[4] == 0, "the prime spot: centred over the bar")
assert(YaHT.ProcSlotShift(db, "mongoose") == db.procsize + 2 + 6 and m.point[4] == db.procsize + 2 + 6, "the other icons should line up to its right")
run(9) assert(math.abs(b.timer.width / db.procsize - 0.5) < 0.04, "its timer should run down over 18 seconds")
run(9.2) assert(not b.proc, "it stayed past 18 seconds")
run(0.5) assert(not b.shown and not w.shown, "it should go away and the watcher sleep")
-- SECONDS LEFT: a number on the icon while it lasts (an option)
cast(19574) run(0.6)
assert(b.cdText.shown and b.cdText.txt == "18" and not b.icon.desat, "the seconds left should show on the icon: "..tostring(b.cdText.txt))
run(10) assert(b.cdText.txt == "8", "the number should count down: "..tostring(b.cdText.txt))
db.bestialnumbers = false run(0.2)
assert(not b.cdText.shown, "seconds left switched off still show")
db.bestialnumbers = true run(8) run(0.5)
assert(not b.proc and not b.shown, "without the cooldown option it should go when its time is up")
-- ITS COOLDOWN: after the 18 seconds the icon stays, grey with a countdown, until it can be cast again
db.bestialcooldown = true
local c0 = GetTime()
cast(19574) run(1)
assert(b.proc and b.icon.desat ~= true and b.cdText.txt == "17", "while it lasts: in colour, with its seconds")
run(18)
assert(b.proc and b.shown and b.icon.desat == true and b.cdShade.shown, "after its time the icon should stay, grey, for the cooldown")
assert(b.cdText.shown and tonumber(b.cdText.txt) == math.ceil(c0 + 120 - GetTime()), "the cooldown should count down: "..tostring(b.cdText.txt))
assert(b.timer.width < 1, "the timer line is for its 18 seconds, not the cooldown")
run(100)
assert(b.proc and b.icon.desat == true, "still on cooldown")
run(1.5)
assert(b.proc and b.icon.desat == false, "ready again: back in colour for a moment")
run(2)
assert(not b.proc, "and then it goes away")
run(0.5) assert(not b.shown and not w.shown, "nothing left running")
-- the game's own cooldown length is used when it gives one
C_Spell.GetSpellCooldown = function(id) if id == 19574 then return {startTime = GetTime() - 0.2, duration = 90} end return {startTime = 0, duration = 0} end
cast(19574) run(19)
assert(b.proc and b.cdDur == 90 and tonumber(b.cdText.txt) <= 72, "the game's own cooldown should be used: "..tostring(b.cdDur).." "..tostring(b.cdText.txt))
run(75) assert(not b.proc, "gone after the real cooldown")
C_Spell.GetSpellCooldown = nil
db.bestialcooldown = false
-- other spells don't set it off; switched off, it doesn't show and gives its place back
cast(3045) run(0.2) assert(not b.proc, "another spell set it off")
db.bestial = false YaHT:ApplySettings()
cast(19574) run(0.2)
assert(not b.proc and not b.shown and YaHT.ProcSlotShift(db, "mongoose") == 0, "switched off: no icon, and its place given back")
db.bestial = true YaHT:ApplySettings()
-- placed somewhere else, the centre is the next icon's again
db.bestialpos = "LEFT" YaHT:ApplySettings()
assert(b.point[1] == "RIGHT" and YaHT.ProcSlotShift(db, "mongoose") == 0, "left of the bar: Mongoose Bite is centred again")
db.bestialpos = "ABOVE" YaHT:ApplySettings()
-- it takes the shared look like the others (round, polished), and its own page exists
db.procshape, db.procpolish = "CIRCLE", true YaHT:ApplySettings()
assert(b.isRound and b.round.back.shown, "it should take the shared shape")
db.procshape, db.procpolish = "SQUARE", false YaHT:ApplySettings()
local procs = YaHT.optionsTable.args.alerts.args.procspage.args
assert(procs.bestial and procs.bestialpage and procs.bestialpage.args.bestialpos and procs.bestial.name == "Bestial Wrath", "no Bestial Wrath settings")
assert(procs.bestialpage.args.bestialnumbers and procs.bestialpage.args.bestialcooldown, "Bestial Wrath's page is missing its seconds and cooldown options")
-- "Show seconds left" works on every proc icon (off to start with on the older ones)
local r = YaHT.rapidFireFrame
assert(db.rapidfirenumbers == false, "the older icons should not show numbers until asked")
cast(3045) for k = 1, 12 do advance(dt) r.scripts.OnUpdate(r, dt) end
assert(r.proc and not r.cdText.shown, "Rapid Fire showed a number without being asked")
db.rapidfirenumbers = true for k = 1, 4 do advance(dt) r.scripts.OnUpdate(r, dt) end
assert(r.cdText.shown and r.cdText.txt == "15", "Rapid Fire should show its seconds when asked: "..tostring(r.cdText.txt))
db.rapidfirenumbers = false
assert((YaHT.errorCount or 0) == 0, "YaHT reported a problem")
print("OK43")
