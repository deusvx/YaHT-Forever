-- Real log (517857): a shot leaves while an Aimed Shot cast is still running;
-- on Forever the NEXT shot then comes ~0.15-0.27s late. That cycle must not
-- teach the learned delay. Plain cycles afterwards still do.
local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local db=YaHT.db.profile local f=YaHT.mainFrame
db.lock=true YaHT:ApplySettings() f.speed=2.091
local dt=0.002 local function run(sec) for k=1,math.floor(sec/dt+0.5) do advance(dt) f.scripts.OnUpdate(f,dt) end end

YaHT.calib = 0 YaHT.calibSamples = 0
fire("START_AUTOREPEAT_SPELL") run(0.09)
fire("UNIT_SPELLCAST_SENT","player","t","g",75) run(0.10)
fire("UNIT_SPELLCAST_START","player","g",19434) run(0.35)       -- Aimed Shot cast starts
fire("PLAYER_SWING", 2.091, 2)                                   -- shot leaves mid-cast
fire("PLAYER_SWING", 2.091, 2)                                   -- (shot 2: start a cycle with casting=true)
run(1.0)
fire("UNIT_SPELLCAST_SUCCEEDED","player","g",19434) fire("UNIT_SPELLCAST_STOP","player","g",19434)
run(1.247)
fire("PLAYER_SWING", 2.091, 2)                                   -- late shot: 2.247s
local afterLate = YaHT.calib
print(string.format("learned delay after the Aimed-Shot-delayed shot: %+.3f (%d samples)", afterLate, YaHT.calibSamples))
assert(math.abs(afterLate) < 0.001, "delayed cycle after an Aimed Shot was learned")

-- three clean shots 2.111s apart: these should teach a small +delay
for i=1,3 do run(2.111) fire("PLAYER_SWING", 2.091, 2) end
print(string.format("learned delay after clean shots: %+.3f (%d samples)", YaHT.calib, YaHT.calibSamples))
assert(YaHT.calibSamples >= 2 and YaHT.calib > 0, "clean shots stopped teaching the delay")
print("OK21")
