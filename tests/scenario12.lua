local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local db=YaHT.db.profile local f=YaHT.mainFrame
db.lock=true YaHT:ApplySettings()
print("SENT registered:", ev.events.UNIT_SPELLCAST_SENT == true)
local D, W = 2.273, 0.5*2.273/2.8
local jitter = {-0.09, 0.07, -0.02, 0.05, -0.09, 0.05, -0.08, 0.06, -0.03, 0.04}  -- like your log
local dt=0.005
local function tick() advance(dt) f.scripts.OnUpdate(f,dt) end
local function run(useSent, label)
  YaHT.calib=nil
  fire("START_AUTOREPEAT_SPELL")
  local t=0 local realShot=W local castStart=0 local errs={}
  for shot=1,10 do
    local predicted
    local arrive = realShot + (shot>1 and jitter[shot] or 0) -- PLAYER_SWING arrives with jitter
    while t < arrive - 1e-9 do
      if useSent and math.abs(t - castStart) < dt/2 then fire("UNIT_SPELLCAST_SENT","player","target","g",75) end
      tick() t=t+dt
      if not predicted and f.SwingStart and (GetTime()-f.SwingStart) >= (f.windup or W) - 1e-9 then predicted=t end
    end
    fire("PLAYER_SWING", D, 2)
    table.insert(errs, string.format("%+.2f", (predicted or t) - realShot))
    castStart = realShot + D - W
    realShot = realShot + D       -- real shots evenly spaced
  end
  print(label, table.concat(errs," "))
  fire("STOP_AUTOREPEAT_SPELL") for i=1,800 do tick() end
end
run(false, "event-jitter, no SENT  (bar vs real shot):")
run(true,  "event-jitter, with SENT (bar vs real shot):")
print("OK12")
