-- On Forever a melee swing restarts the shot's reload (a shot does not restart the melee swing).
-- The bar used to carry on as if nothing had happened, and showed a shot as due a whole reload early.
local ev, mev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
for _,f in ipairs(frames) do if f.events.PLAYER_ENTER_COMBAT then mev=f end end
local db=YaHT.db.profile local f=YaHT.mainFrame
db.lock=true db.width=200 db.fill=false YaHT:ApplySettings()
local function tick(n,dt) for i=1,n do advance(dt) f.scripts.OnUpdate(f,dt) end end
local function melee(hand) mev.scripts.OnEvent(mev, "PLAYER_SWING", 3.4, hand or 0) end
fire("START_AUTOREPEAT_SPELL") fire("PLAYER_SWING", 2.4, 2)
local shotAt = f.lastshot
tick(150, 0.01)                       -- 1.5 s into a reload of about 1.9 s: the bar is nearly run down
local low = f.texture.width
melee()                               -- the main hand swings
local swungAt = GetTime()
assert(f.lastshot == swungAt, "a melee swing should restart the reload")
tick(1, 0.01)
assert(f.texture.width > low + 80, "the bar should show a fresh reload, got "..f.texture.width.." after "..low)
tick(120, 0.01) assert(not f.SwingStart, "1.2 s after the swing the shot is not due yet")
tick(90, 0.01) assert(f.SwingStart, "a whole reload after the swing the stand-still part runs")
-- the off hand does not count; a shot does not come from a melee swing
fire("PLAYER_SWING", 2.4, 2) local s2 = f.lastshot
tick(50, 0.01) melee(1) assert(f.lastshot == s2, "an off-hand swing restarts nothing")
-- switched off: as before
db.meleeresets = false melee() assert(f.lastshot == s2, "switched off, a melee swing must not restart the reload")
db.meleeresets = true
assert((YaHT.errorCount or 0) == 0, tostring(YaHT.lastError))
local page = YaHT.optionsTable.args.advanced.args.timingpage.args
assert(page.meleeresets and page.feignresets, "both switches should be on the Timing page")
print("OK63")
