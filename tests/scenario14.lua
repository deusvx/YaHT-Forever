local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local db=YaHT.db.profile local f=YaHT.mainFrame
db.lock=true YaHT:ApplySettings() YaHT.calib=0.046
local D=2.273 local W=0.5*D/2.8 local dt=0.002
local function tick() advance(dt) f.scripts.OnUpdate(f,dt) end
-- replay from your log: shot at 411.156, attempt failed at 412.986, next shot 413.954
local t0=GetTime() local base=411.156
local function now() return GetTime()-t0+base end
fire("START_AUTOREPEAT_SPELL") fire("PLAYER_SWING", D, 2)
local failed=false local predicted
while now() < 413.954 do
  tick()
  if not failed and now() >= 412.986 then fire("UNIT_SPELLCAST_FAILED_QUIET","player","g",75) failed=true end
  if failed and not predicted and f.SwingStart and (GetTime()-f.SwingStart) >= (f.windup or W)-1e-9 then predicted=now() end
end
print(string.format("failed attempt: bar says shot at %.3f, real shot 413.954 -> off by %+.3f", predicted or -1, (predicted or 0)-413.954))
-- calibration speed: feed alternating jitter, learned delay should stay calm
YaHT.calib=0 local lo,hi=1,-1
fire("PLAYER_SWING", D, 2)
local j={0.097,0.050,-0.033,0.029,-0.058,-0.021,-0.041,-0.021,-0.007,0.079,-0.009,-0.039,0.001,-0.014,0.034}
for i=1,#j do
  local target=GetTime()+D+0.01+j[i]
  while GetTime()<target do tick() end
  fire("PLAYER_SWING", D, 2)
  if i>3 then lo=math.min(lo,YaHT.calib) hi=math.max(hi,YaHT.calib) end
end
print(string.format("learned delay range after warm-up: %+.3f .. %+.3f (was -0.030..+0.046)", lo, hi))
print("OK14")
