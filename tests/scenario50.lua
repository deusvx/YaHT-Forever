-- Raptor Strike queued (1.5.1): while it waits for your next melee swing its icon shows next to the bar,
-- with a timer that runs down to the swing; it goes when the swing lands or the queue is cancelled.
local names = {[2973] = "Raptor Strike", [1495] = "Mongoose Bite"}
local oldName = C_Spell.GetSpellName
C_Spell.GetSpellName = function(id) return names[id] or oldName(id) end
C_Spell.GetSpellTexture = function(id) return "icon"..tostring(id) end
local queued = false
C_Spell.IsCurrentSpell = function(id) return queued and id == 14266 end -- (a higher rank counts too)
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db = YaHT.db.profile
local r, w, m = YaHT.raptorFrame, YaHT.raptorWatch, YaHT.meleeFrame
assert(r and w and m, "no Raptor Strike icon")
assert(db.raptor == true and db.raptorpos == "ABOVE", "it should start out switched on, above the bar")
local dt = 0.05
local function run(sec) for k = 1, math.floor(sec/dt + 0.5) do advance(dt)
  if w.shown then w.scripts.OnUpdate(w, dt) end
  if r.shown then r.scripts.OnUpdate(r, dt) end end end
local function fire(e) w.scripts.OnEvent(w, e) end
db.lock = true YaHT:ApplySettings()
run(0.3) assert(not r.shown and not w.shown, "nothing queued: no icon, and the watcher asleep")

-- you press Raptor Strike 1 second into a 3 second swing: the icon pops in, its timer runs to the swing
m.swingStart, m.swingDur = GetTime() - 1, 3
queued = true fire("CURRENT_SPELL_CAST_CHANGED") run(0.1)
assert(r.proc and r.shown and r.icon.tex == "icon2973", "queued: its icon should show: "..tostring(r.icon.tex))
assert(math.abs(r.window - 2) < 0.11, "the timer should be the time left to the swing: "..tostring(r.window))
run(0.9) assert(math.abs(r.timer.width / db.procsize - 0.5) < 0.08, "half way to the swing the timer should be half: "..tostring(r.timer.width))
-- the swing lands: the game takes it off the queue, the icon goes
queued = false fire("CURRENT_SPELL_CAST_CHANGED") run(0.1)
assert(not r.proc, "the swing landed: the icon should go")
run(0.6) assert(not r.shown and not w.shown, "gone, and the watcher asleep again")
-- without a known swing it still shows (a full weapon swing as its length)
m.swingStart, m.swingDur = nil, nil
queued = true fire("CURRENT_SPELL_CAST_CHANGED") run(0.2)
assert(r.proc and r.window == 3, "no swing known: still shown: "..tostring(r.window))
-- no event at all when it leaves the queue: the ten-times-a-second look catches it
queued = false run(0.3) assert(not r.proc, "it should notice by itself that it is no longer queued")
run(0.6)
-- switched off: nothing
db.raptor = false YaHT:ApplySettings()
queued = true fire("CURRENT_SPELL_CAST_CHANGED") run(0.2)
assert(not r.proc and not r.shown, "switched off it must not show")
db.raptor = true YaHT:ApplySettings() queued = false run(0.3)
-- it stands after the other icons above the bar, and moves nobody
assert(YaHT.ProcSlotShift(db, "mongoose") == 0 and YaHT.ProcSlotShift(db, "raptor") == db.procsize + 2 + 6, "it should stand to the right of Mongoose Bite")
-- its page, with the same settings as the other icons
local procs = YaHT.optionsTable.args.alerts.args.procspage.args
assert(procs.raptor and procs.raptor.name == "Raptor Strike" and procs.raptorpage, "no Raptor Strike settings")
local pa = procs.raptorpage.args
assert(pa.raptor and pa.raptorpos and pa.raptorsize and pa.raptorshape and pa.raptormore and pa.raptorglowcolor, "its page is missing settings")
-- in "Preview all alerts"
YaHT:PreviewAlerts() run(0.2) assert(r.shown and r.proc, "it should take part in the preview")
assert((YaHT.errorCount or 0) == 0, "YaHT reported a problem: "..tostring(YaHT.lastError))
print("OK50")
