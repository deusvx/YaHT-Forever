local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local db=YaHT.db.profile local f=YaHT.mainFrame
db.lock=true YaHT:ApplySettings() f.speed=2.273
local dt=0.002 local function run(sec) for k=1,math.floor(sec/dt) do advance(dt) f.scripts.OnUpdate(f,dt) end end
-- your log 154.100: START, SENT+FAIL, SENT+FAIL(.563), late real retry FAIL at +0.594, FAIL again +0.505
fire("START_AUTOREPEAT_SPELL") run(0.125)
fire("UNIT_SPELLCAST_SENT","player","t","g",75) fire("UNIT_SPELLCAST_FAILED_QUIET","player","g",75) run(0.338)
fire("UNIT_SPELLCAST_SENT","player","t","g",75) fire("UNIT_SPELLCAST_FAILED_QUIET","player","g",75) run(0.594)
local before=f.SwingStart fire("UNIT_SPELLCAST_FAILED_QUIET","player","g",75)
print("late real retry accepted (re-aligned):", f.SwingStart ~= before, string.format("next attempt in %.3fs", f.nextAttempt-GetTime()))
print("OK17")
