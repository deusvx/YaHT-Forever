-- Raptor Strike queued (1.5.1): while it waits for your next melee swing its icon shows next to the bar,

-- with a timer that runs down to the swing; it goes when the swing lands or the queue is cancelled.

local names = {[2973] = "Raptor Strike", [1495] = "Mongoose Bite"}

local oldName = C_Spell.GetSpellName

C_Spell.GetSpellName = function(id) return names[id] or oldName(id) end

C_Spell.GetSpellTexture = function(id) return "icon"..tostring(id) end

local queued = false
C_Spell.GetSpellCooldown = function() return {startTime = 0, duration = 0} end -- (no cooldown, until a test sets one)

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

-- AFTER THE STRIKE LANDS its cooldown shows on the icon (grey, clock sweep, countdown), and the icon
-- goes when the cooldown is over. A cancelled queue has no cooldown: the icon just goes, as before.
do
  assert(db.raptorafter == true, "the cooldown after the strike should start out on")
  local cdS, cdD = 0, 0
  local oldCD = C_Spell.GetSpellCooldown
  C_Spell.GetSpellCooldown = function() return {startTime = cdS, duration = cdD} end
  m.swingStart, m.swingDur = GetTime() - 2, 3
  queued = true fire("CURRENT_SPELL_CAST_CHANGED") run(0.2)
  assert(r.proc and not r.afterUse and not r.cdShade.shown, "queued: in colour, as it was")
  run(0.8) queued = false cdS, cdD = GetTime(), 6 fire("CURRENT_SPELL_CAST_CHANGED") run(0.1)
  assert(r.proc and r.afterUse and r.shown, "the strike landed: the icon should stay for its cooldown")
  assert(r.cdShade.shown and r.cdText.shown and r.cdText.txt == "6", "grey with the seconds left: "..tostring(r.cdText.txt))
  run(3) assert(r.proc and (r.cdText.txt == "3" or r.cdText.txt == "2.9" or r.cdText.txt == "3.0"), "it counts down: "..tostring(r.cdText.txt))
  run(3.1) assert(not r.proc, "cooldown over: the icon goes")
  cdS, cdD = 0, 0 run(0.6) assert(not r.shown and not w.shown, "gone, and the watcher asleep again")
  -- cancelled: no cooldown, the icon just goes
  queued = true fire("CURRENT_SPELL_CAST_CHANGED") run(0.2) queued = false fire("CURRENT_SPELL_CAST_CHANGED") run(0.1)
  assert(not r.proc, "cancelled: no cooldown to show") run(0.6)
  -- an older cooldown still running when the queue is cancelled is not "it landed"... (cannot happen in
  -- the game, but a cooldown from before this queue must never count)
  -- the game hides the cooldown (a fight): the cast it reports, and the usual 6 seconds, stand in
  local cw = YaHT.castBuffWatch
  C_Spell.GetSpellCooldown = function() return SECRET end
  queued = true fire("CURRENT_SPELL_CAST_CHANGED") run(0.2)
  queued = false cw.scripts.OnEvent(cw, "UNIT_SPELLCAST_SUCCEEDED", "player", "g", 2973) fire("CURRENT_SPELL_CAST_CHANGED") run(0.1)
  assert(r.proc and r.afterUse and r.cdDur == 6, "hidden cooldown: the cast should start the usual 6 seconds")
  -- pressed again as soon as it is ready while the icon still shows: a fresh queue, in colour
  run(5.5) queued = true fire("CURRENT_SPELL_CAST_CHANGED") run(0.2)
  assert(r.proc and not r.afterUse and not r.cdShade.shown, "queued again: the queued look again")
  queued = false fire("CURRENT_SPELL_CAST_CHANGED") run(0.7)
  -- hidden, and no cast said: nothing to show
  queued = true fire("CURRENT_SPELL_CAST_CHANGED") run(0.2) queued = false fire("CURRENT_SPELL_CAST_CHANGED") run(0.1)
  assert(not r.proc) run(0.6)
  -- the word comes a moment after the queue ends: the icon comes back for the cooldown
  C_Spell.GetSpellCooldown = function() return {startTime = cdS, duration = cdD} end
  inFight = true
  queued = true fire("CURRENT_SPELL_CAST_CHANGED") run(0.2) queued = false fire("CURRENT_SPELL_CAST_CHANGED") run(0.1)
  if not r.proc and w.shown then cdS, cdD = GetTime() - 0.1, 6 run(0.2) assert(r.proc and r.afterUse, "a cooldown that shows up a moment late should still be shown") run(6) end
  cdS, cdD = 0, 0
  -- the setting off: as it always was
  db.raptorafter = false
  queued = true fire("CURRENT_SPELL_CAST_CHANGED") run(0.2) queued = false cdS, cdD = GetTime(), 6 fire("CURRENT_SPELL_CAST_CHANGED") run(0.1)
  assert(not r.proc, "switched off: the icon goes when the swing lands")
  db.raptorafter = true cdS, cdD = 0, 0 run(0.6)
  C_Spell.GetSpellCooldown = oldCD
  local pa = YaHT.optionsTable.args.alerts.args.procspage.args
  assert(pa.raptorpage.args.raptorafter and pa.mongoosepage.args.mongooseafter, "each page should have the switch for it")
  assert(YaHT:IsNew("key", "raptorafter") and YaHT:IsNew("key", "mongooseafter"), "made new, so marked New")
  assert((YaHT.errorCount or 0) == 0, tostring(YaHT.lastError))
end
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

