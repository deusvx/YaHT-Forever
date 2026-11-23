-- "Sound at seconds left" (1.5): one warning sound as an icon's time passes the mark you set.
local names = {[19574] = "Bestial Wrath", [3045] = "Rapid Fire", [1495] = "Mongoose Bite"}
local oldName = C_Spell.GetSpellName
C_Spell.GetSpellName = function(id) return names[id] or oldName(id) end
C_Spell.GetSpellTexture = function(id) return "icon"..tostring(id) end
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db = YaHT.db.profile
SOUNDKIT = SOUNDKIT or {}
SOUNDKIT.ALARM_CLOCK_WARNING_3 = 12889
-- (the stand-in keeps every sound played in `sounds`)
local function lows() local n = 0 for _, k in ipairs(sounds) do if k == 12889 then n = n + 1 end end return n end
local r, w = YaHT.rapidFireFrame, YaHT.castBuffWatch
local dt = 0.05
local function run(sec) for k = 1, math.floor(sec/dt + 0.5) do advance(dt)
  if w.shown then w.scripts.OnUpdate(w, dt) end
  if r.shown then r.scripts.OnUpdate(r, dt) end end end
local function cast(id) w.scripts.OnEvent(w, "UNIT_SPELLCAST_SUCCEEDED", "player", "g", id) end
db.lock = true YaHT:ApplySettings()
assert(db.rapidfiresoundat == 0 and db.hawksoundat == 0, "no sound until asked")

-- off: Rapid Fire runs its 15 seconds in silence
cast(3045) run(16)
assert(lows() == 0, "a sound without being asked")
-- at 5 seconds left: exactly one sound, as the time passes the mark
db.rapidfiresoundat = 5
cast(3045) run(9.5)
assert(lows() == 0, "too early: "..lows())
run(1)
assert(lows() == 1, "one sound when 5 seconds are left, got "..lows())
run(6)
assert(lows() == 1, "it should sound once per run, got "..lows())
-- the next run sounds again
cast(3045) run(11)
assert(lows() == 2, "the next run should sound again, got "..lows())
run(6)
-- a mark longer than the run never sounds (it would ring the moment the icon appears)
db.rapidfiresoundat = 15
cast(3045) run(16)
assert(lows() == 2, "a mark as long as the run must not ring at its start, got "..lows())
db.rapidfiresoundat = 0

-- the hawks: one sound per hawk as it passes the mark (6 seconds: time to summon again)
do
  names[1293241] = "Summon Hawk"
  local hw = YaHT.hawkWatch
  local function hrun(sec) for k = 1, math.floor(sec/dt + 0.5) do advance(dt) if hw.shown then hw.scripts.OnUpdate(hw, dt) end end end
  local before = lows()
  db.hawksoundat = 6
  hw.scripts.OnEvent(hw, "UNIT_SPELLCAST_SUCCEEDED", "player", "g", 1293241)
  hrun(11.5) assert(lows() == before, "too early for the hawk's sound")
  hrun(1) assert(lows() == before + 1, "one sound when the hawk has 6 seconds left, got "..(lows() - before))
  hrun(7) assert(lows() == before + 1, "once per hawk")
  db.hawksoundat = 0
end
-- its setting is on every timed icon's page and on the Hawks page
local alerts = YaHT.optionsTable.args.alerts.args
for _, key in ipairs({"bestial", "mongoose", "quickshots", "rapidfire", "racial"}) do
  assert(alerts.procspage.args[key.."page"].args[key.."soundat"], key.." has no Sound at seconds left")
end
assert(alerts.hawkpage.args.hawksoundat, "the Hawks page has no Sound at seconds left")
assert((YaHT.errorCount or 0) == 0, "YaHT reported a problem")
print("OK47")
