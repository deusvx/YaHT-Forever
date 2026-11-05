local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local db=YaHT.db.profile local f=YaHT.mainFrame
db.lock=true YaHT:ApplySettings() f.speed=2.273 -- your weapon speed at login
local D=2.273 local dt=0.002
function UnitRangedDamage() return 2.273 end  -- match your weapon before the first shot
-- replay helper: events = {{time, name}}, moving windows, measure bar's shot moment vs a real shot time
local function replay(label, startT, events, moves, realShot)
  local t=startT local i=1 local predicted
  local function mv(x) for _,w in ipairs(moves or {}) do if x>=w[1] and x<w[2] then return true end end return false end
  while t < realShot + 0.3 do
    while events[i] and events[i][1] <= t do
      local n=events[i][2]
      if n=="SWING" then fire("PLAYER_SWING", D, 2)
      elseif n=="SENT" then fire("UNIT_SPELLCAST_SENT","player","t","g",75)
      elseif n=="FAIL" then fire("UNIT_SPELLCAST_FAILED_QUIET","player","g",75)
      else fire(n) end
      i=i+1
    end
    _G.moving = mv(t)
    advance(dt) f.scripts.OnUpdate(f,dt) t=t+dt
    if t < realShot + 0.25 and not predicted and f.SwingStart and GetTime() >= f.SwingStart + (f.windup or 0.4) - 1e-9 and t > realShot - 1.2 then predicted=t end
  end
  print(string.format("%-46s bar shot %+.3f vs real", label, (predicted or 99)-realShot))
  fire("STOP_AUTOREPEAT_SPELL") for k=1,3000 do advance(dt) f.scripts.OnUpdate(f,dt) end
end
-- windup on the test weapon (base 2.8) is 0.406, so scale your log's 0.455 gaps: use real shot = SENT/attempt + 0.406
local W=0.5*D/2.8
replay("first shot (START, SENT +0.175)", 0, {{0,"START_AUTOREPEAT_SPELL"},{0.175,"SENT"}}, nil, 0.175+W)
replay("start, SENT+FAIL together -> retry", 0, {{0,"START_AUTOREPEAT_SPELL"},{0.119,"SENT"},{0.119,"FAIL"}}, nil, 0.119+0.5+W)
-- A: in a run: shot at 0, fail at reload end, extra SENT+FAIL during the retry wind-up
replay("A: extra SENT+FAILx2 during retry wind-up", 0,
  {{0,"START_AUTOREPEAT_SPELL"},{0,"SWING"},{D-W+0.0,"FAIL"},{D-W+0.5+0.236,"SENT"},{D-W+0.5+0.236,"FAIL"},{D-W+0.5+0.236,"FAIL"}},
  {{D-W-0.05, D-W+0.02}}, D-W+0.5+W)
-- B: start while moving, fails, manual press (SENT off-rhythm), extra fails during its wind-up
replay("B: manual press off-rhythm + extra fails", 0,
  {{0,"START_AUTOREPEAT_SPELL"},{0.126,"SENT"},{0.126,"FAIL"},{0.653,"FAIL"},{0.887,"SENT"},{1.18,"FAIL"},{1.18,"FAIL"}},
  {{0.0, 0.70}}, 0.887+W)
-- calibration ignores restarts
YaHT.calib=0.008
fire("START_AUTOREPEAT_SPELL") fire("PLAYER_SWING", D, 2)
for k=1,math.floor(2.0/dt) do advance(dt) f.scripts.OnUpdate(f,dt) end
fire("STOP_AUTOREPEAT_SPELL") for k=1,math.floor(0.6/dt) do advance(dt) f.scripts.OnUpdate(f,dt) end
fire("START_AUTOREPEAT_SPELL") for k=1,math.floor(0.3/dt) do advance(dt) f.scripts.OnUpdate(f,dt) end
fire("UNIT_SPELLCAST_SENT","player","t","g",75) for k=1,math.floor(0.4/dt) do advance(dt) f.scripts.OnUpdate(f,dt) end
fire("PLAYER_SWING", D, 2)
print(string.format("learned delay after a stop/restart cycle: %+.3f (should stay +0.008)", YaHT.calib))
print("OK16")
