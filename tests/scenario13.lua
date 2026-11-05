local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local db=YaHT.db.profile local f=YaHT.mainFrame
db.lock=true YaHT:ApplySettings()
-- your real PLAYER_SWING arrival times (2nd + 3rd runs), merged as one long run
local arr = {197.891,200.095,202.457,204.695}
local arr2 = {212.898,215.208,217.516,219.806,222.071}
-- true shots: least-squares straight line through each run
local function fit(a) local n=#a local sx,sy,sxx,sxy=0,0,0,0 for i=1,n do sx=sx+i sy=sy+a[i] sxx=sxx+i*i sxy=sxy+i*a[i] end
  local b=(n*sxy-sx*sy)/(n*sxx-sx*sx) return function(i) return (sy-b*sx)/n + b*i end, b end
local D=2.273 local dt=0.002
local function tick() advance(dt) f.scripts.OnUpdate(f,dt) end
local function run(a, smooth)
  db.smooth=smooth YaHT.calib=0.012
  local truth, period = fit(a)
  -- align clock to first arrival
  local t0 = GetTime() local base = a[1]
  fire("START_AUTOREPEAT_SPELL")
  fire("PLAYER_SWING", D, 2)
  local errs, sum = {}, 0
  for i=2,#a do
    local predicted
    while GetTime() - t0 + base < a[i] - 1e-9 do
      tick()
      if not predicted and f.SwingStart and (GetTime()-f.SwingStart) >= (f.windup or 0.4) - 1e-9 then predicted = GetTime() - t0 + base end
    end
    fire("PLAYER_SWING", D, 2)
    local e = (predicted or a[i]) - truth(i)
    table.insert(errs, string.format("%+.3f", e)) sum = sum + math.abs(e)
  end
  fire("STOP_AUTOREPEAT_SPELL") for k=1,3000 do tick() end
  return table.concat(errs," "), sum/(#a-1)
end
for _,a in ipairs({arr, arr2}) do
  local e1,m1 = run(a,false) local e2,m2 = run(a,true)
  print(string.format("raw (old):  %s   avg off %.3f", e1, m1))
  print(string.format("smoothed:   %s   avg off %.3f", e2, m2))
end
print("OK13")
