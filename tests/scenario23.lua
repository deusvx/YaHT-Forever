-- Real log (518649.996 .. 518652.229): the bar starts its own red wind-up at the
-- predicted end of the reload (651.647), but the game's real wind-up starts
-- 0.154s later (a key press, SENT on its own, not refused). That SENT used to be
-- dropped as an "extra request" (0.15s rule) and the bar finished 0.13s early.
-- A real SENT must re-sync; SENT + FAILED duplicates during the wind-up must not.
local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local db=YaHT.db.profile local f=YaHT.mainFrame
db.lock=true YaHT:ApplySettings() f.speed=2.091
local dt=0.002 local function run(sec) for k=1,math.floor(sec/dt+0.5) do advance(dt) f.scripts.OnUpdate(f,dt) end end
YaHT.calib = 0.015

fire("START_AUTOREPEAT_SPELL") run(0.05)
fire("UNIT_SPELLCAST_SENT","player","t","g",75) run(0.45)
fire("PLAYER_SWING", 2.091, 2)                      -- 649.996: shot
local shot = GetTime()
run(1.387) fire("UNIT_SPELLCAST_SENT","player","t","g",75) fire("UNIT_SPELLCAST_FAILED_QUIET","player","g",75) -- 651.383 refused press
run(0.418)                                          -- 651.801
local guess = f.SwingStart
fire("UNIT_SPELLCAST_SENT","player","t","g",75)     -- real wind-up start (not refused)
local realAt = GetTime()
run(0.06)
print(string.format("bar's own guess %.3fs after shot, real start %.3fs, bar now uses %.3fs",
  (guess or 0) - shot, realAt - shot, (f.SwingStart or 0) - shot))
assert(f.SwingStart and math.abs(f.SwingStart - realAt) < 0.003, "real wind-up start was ignored")

-- duplicates during the wind-up: SENT + FAILED together, must change nothing
run(0.04) local before = f.SwingStart
fire("UNIT_SPELLCAST_SENT","player","t","g",75) fire("UNIT_SPELLCAST_FAILED_QUIET","player","g",75) fire("UNIT_SPELLCAST_FAILED_QUIET","player","g",75)
run(0.10)
fire("UNIT_SPELLCAST_SENT","player","t","g",75) fire("UNIT_SPELLCAST_FAILED_QUIET","player","g",75) fire("UNIT_SPELLCAST_FAILED_QUIET","player","g",75)
run(0.06)
print("duplicates left the wind-up alone:", f.SwingStart == before)
assert(f.SwingStart == before, "a refused duplicate moved the wind-up")
print("OK23")
