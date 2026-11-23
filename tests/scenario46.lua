-- Auto Shot ended without the game saying so (a loading screen swallowed the stop): the bar must not keep
-- coming up on every stop. Without a target for a few seconds it puts itself away.
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db = YaHT.db.profile local f = YaHT.mainFrame
db.lock = true YaHT:ApplySettings()
local hasTarget = true
function UnitExists(u) return hasTarget end
local dt = 0.02
local function run(sec) for k = 1, math.floor(sec/dt + 0.5) do advance(dt) if f.shown then f.scripts.OnUpdate(f, dt) end end end

-- shooting at a target: the bar stays, however long
ev.scripts.OnEvent(ev, "START_AUTOREPEAT_SPELL")
run(8)
assert(f.shooting and f.shown, "with a target the bar should stay up while shooting")
-- the target is gone and no stop ever arrives: a short blink without one is fine...
hasTarget = false run(1.5)
assert(f.shooting and f.shown, "a moment without a target must not put the bar away")
hasTarget = true run(1) hasTarget = false
-- ...but a few seconds without one means Auto Shot is over
run(3.5)
assert(not f.shooting and not f.shown, "the bar should put itself away: shooting "..tostring(f.shooting).." shown "..tostring(f.shown))
-- moving and stopping afterwards brings nothing back
moving = true run(1) moving = false run(2)
assert(not f.shown, "the bar came back on a stop")
-- a new shot run works as before
hasTarget = true
ev.scripts.OnEvent(ev, "START_AUTOREPEAT_SPELL") run(1)
assert(f.shooting and f.shown, "a new Auto Shot run should show the bar again")
-- where the game answers itself: its "no" counts once it has been seen to say "yes"
local auto = true
C_Spell.IsAutoRepeatSpell = function(id) return auto end
run(2) assert(f.shown, "the game says Auto Shot is on")
auto = false run(3.5)
assert(not f.shooting and not f.shown, "the game said Auto Shot is off: the bar should go")
assert((YaHT.errorCount or 0) == 0, "YaHT reported a problem")
print("OK46")
