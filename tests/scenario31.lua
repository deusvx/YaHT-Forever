-- Real log (770955-770964): Rapid Fire + Quick Shots wearing off. The swing
-- time changes 1.422 -> 1.849 -> 2.589 and the cycles around each change are
-- irregular (+0.10s, +0.17s). Those must not teach the learned delay; plain
-- cycles afterwards still do.
local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local db=YaHT.db.profile local f=YaHT.mainFrame
db.lock=true YaHT:ApplySettings() f.speed=1.422
local dt=0.002 local function run(sec) for k=1,math.floor(sec/dt+0.5) do advance(dt) f.scripts.OnUpdate(f,dt) end end

YaHT.calib = 0.020 YaHT.calibSamples = 10
fire("START_AUTOREPEAT_SPELL") run(0.09)
fire("UNIT_SPELLCAST_SENT","player","t","g",75) run(0.216)
fire("PLAYER_SWING", 1.422, 2)            -- 770955.273
run(1.442) fire("PLAYER_SWING", 1.422, 2) -- 770956.715 (clean, same speed)
local before = YaHT.calib
run(1.565) fire("PLAYER_SWING", 1.849, 2) -- 770958.280 Quick Shots gone: speed changed
run(1.804) fire("PLAYER_SWING", 1.849, 2) -- 770960.084 first cycle at the new speed
run(1.954) fire("PLAYER_SWING", 2.589, 2) -- 770962.038 Rapid Fire gone: speed changed (+0.10s)
run(2.681) fire("PLAYER_SWING", 2.589, 2) -- 770964.719 first cycle at the new speed (+0.17s in the log)
print(string.format("learned delay across the speed changes: %+.3f -> %+.3f", before, YaHT.calib))
assert(math.abs(YaHT.calib - before) < 0.004, "cycles around a speed change were learned")

-- steady shots afterwards still teach it
local n = YaHT.calibSamples
for i=1,3 do run(2.609) fire("PLAYER_SWING", 2.589, 2) end
assert(YaHT.calibSamples >= n + 2, "clean shots after the speed change stopped teaching the delay")
print("OK31")
