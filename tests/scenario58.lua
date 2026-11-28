-- Feign Death restarts the shot's reload on Forever, from the moment the feign ENDS. Replay of the
-- one feign whose next shot was timed in the owner's record: cast 0.46 s after a shot (the game
-- gave 2.389 s per shot), up again about 1.3 s after the cast, Auto Shot attempts failing 1.76,
-- 2.18 and 2.76 s after the cast, the shot leaving 3.68 s after it.
local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local db=YaHT.db.profile local f=YaHT.mainFrame
db.lock=true db.width=200 db.fill=false YaHT:ApplySettings()
local feigned = false
function UnitIsFeignDeath() return feigned end
local watch
local function tick(n,dt) for i=1,n do advance(dt) f.scripts.OnUpdate(f,dt)
  watch = watch or YaHT.feignEndWatch
  if watch and watch.shown then watch.scripts.OnUpdate(watch, dt) end end end
fire("START_AUTOREPEAT_SPELL") fire("PLAYER_SWING", 2.389, 2)
local shotAt = f.lastshot
tick(46, 0.01)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-fd", 5384)
local castAt = GetTime()
local function at(t) local n = math.floor((castAt + t - GetTime()) / 0.01 + 0.5) if n > 0 then tick(n, 0.01) end end
assert(f.lastshot == shotAt, "the cast itself restarts nothing yet")
assert(f.disturbed, "a cycle with a feign in it must not teach the timing")
at(0.1) feigned = true
at(1.3) feigned = false
at(1.45)
assert(math.abs(f.lastshot - (castAt + 1.3)) < 0.12, "the reload should restart when the feign ends, got "..(f.lastshot - castAt))
at(1.76) fire("UNIT_SPELLCAST_FAILED_QUIET", "player", "x1", 75)
at(2.18) fire("UNIT_SPELLCAST_FAILED_QUIET", "player", "x2", 75)
at(2.5) assert(not f.SwingStart, "the bar should still be reloading 2.5 s after the cast")
at(2.76) fire("UNIT_SPELLCAST_FAILED_QUIET", "player", "x3", 75)
at(3.45)
assert(f.SwingStart, "by now the stand-still part should run")
local shotDue = f.SwingStart + f.windup - castAt
assert(math.abs(shotDue - 3.68) < 0.15, "the bar should end where the shot really left (3.68 s), got "..shotDue)
at(3.68) fire("PLAYER_SWING", 2.389, 2)

-- a long feign: nothing restarts while you lie there; the reload starts over when you get up
tick(100, 0.01)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-fd2", 5384) castAt = GetTime()
at(0.1) feigned = true
at(6.0) local before = f.lastshot
feigned = false at(6.2)
assert(f.lastshot > before and math.abs(f.lastshot - (castAt + 6.0)) < 0.12, "after a long feign the reload starts over when it ends")
-- a feign that is never seen lying down counts from its cast
tick(300, 0.01)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-fd3", 5384) castAt = GetTime()
at(0.9) assert(math.abs(f.lastshot - castAt) < 0.02, "a feign not seen lying down should count from its cast")
-- switched off: the bar is left alone
db.feignresets = false
tick(300, 0.01) fire("PLAYER_SWING", 2.389, 2) local keep = f.lastshot
tick(50, 0.01) fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-fd4", 5384) tick(150, 0.01)
assert(f.lastshot == keep, "switched off, a feign must not restart the reload")
-- (and a game that hides the answer changes nothing)
db.feignresets = true function UnitIsFeignDeath() return SECRET end
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-fd5", 5384) tick(100, 0.01)
assert((YaHT.errorCount or 0) == 0, tostring(YaHT.lastError))
print("OK58")
