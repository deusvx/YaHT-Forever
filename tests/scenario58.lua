-- Feign Death does not restart the ranged swing on Forever. The bar used to start a whole new
-- reload at the feign, while the game was already trying to shoot (its attempts came 1.2 s and
-- 1.6 s after the feign in the owner's log). The reload must carry on from the last shot.
local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local db=YaHT.db.profile local f=YaHT.mainFrame
db.lock=true YaHT:ApplySettings()
local function tick(n,dt) for i=1,n do advance(dt) f.scripts.OnUpdate(f,dt) end end
fire("START_AUTOREPEAT_SPELL") fire("PLAYER_SWING", 2.24, 2)
local shotAt = f.lastshot
tick(100, 0.01)                                        -- one second into the reload
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-fd", 5384)
local castAt = GetTime()
assert(f.lastshot == shotAt, "Feign Death must not restart the reload")
assert(f.disturbed, "a cycle with a feign in it must not teach the timing")
tick(100, 0.01)                                        -- two seconds after the shot: the reload (about 1.8 s) is over
assert(f.SwingStart, "the bar should be in its stand-still part by now, not in a new reload")
-- For about three seconds after the feign the game lets no Auto Shot start (its attempts fail, half a
-- second apart): the bar shows "ready, waiting" (as when you move with the shot ready), not a
-- stand-still part the game is about to refuse. Replay of the timed feign in the owner's record:
-- attempts failed 1.76, 2.18 and 2.76 s after the cast, the shot left at 3.68 s.
local function at(t) local n = math.floor((castAt + t - GetTime()) / 0.01 + 0.5) if n > 0 then tick(n, 0.01) end end
at(1.76) fire("UNIT_SPELLCAST_FAILED_QUIET", "player", "x1", 75)
at(2.0)
assert(f.readyMoving, "within three seconds of the feign the bar should wait")
assert(f.texture.width < 2, "no stand-still fill in that time, got "..f.texture.width)
at(2.18) fire("UNIT_SPELLCAST_FAILED_QUIET", "player", "x2", 75)
at(2.76) fire("UNIT_SPELLCAST_FAILED_QUIET", "player", "x3", 75)
at(2.95) assert(f.readyMoving and f.texture.width < 2, "still waiting just before the three seconds are over")
at(3.45) assert(not f.readyMoving and f.texture.width > 20, "then one real stand-still part runs, got "..f.texture.width)
local shotDue = f.SwingStart + f.windup - castAt
assert(math.abs(shotDue - 3.68) < 0.12, "the bar should end where the shot really left (3.68 s), got "..shotDue)
at(3.68) fire("PLAYER_SWING", 2.24, 2)
-- an attempt that still fails just after the three seconds: no empty pause, the bar keeps waiting
-- for the next attempt and then fills
tick(190, 0.01)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-fd3", 5384) castAt = GetTime()
at(2.6) fire("UNIT_SPELLCAST_FAILED_QUIET", "player", "y1", 75)
at(3.1) fire("UNIT_SPELLCAST_FAILED_QUIET", "player", "y2", 75)
at(3.4) assert(f.readyMoving and f.texture.width < 2, "a failure just after the hold should keep the bar waiting")
at(3.85) assert(not f.readyMoving and f.texture.width > 20, "and the fill should follow the next attempt")
at(4.05) fire("PLAYER_SWING", 2.24, 2)
-- still lying feigned after the three seconds: the bar keeps waiting
tick(190, 0.01)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-fd2", 5384)
local feigned = true
function UnitIsFeignDeath() return feigned end
tick(400, 0.01)
assert(f.readyMoving and f.texture.width < 2, "while you lie feigned the bar should wait, however long")
feigned = false tick(70, 0.01)
assert(not f.readyMoving, "once you are up the stand-still part should run")
-- (and a game that hides the answer changes nothing)
function UnitIsFeignDeath() return SECRET end
tick(5, 0.01) assert((YaHT.errorCount or 0) == 0, tostring(YaHT.lastError))
print("OK58")
