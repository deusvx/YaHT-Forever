local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local db=YaHT.db.profile local f=YaHT.mainFrame
db.lock=true YaHT:ApplySettings() YaHT.calib=0
local D=2.273 local W=0.5*D/2.8 local dt=0.002
local T=0 local function tick() advance(dt) T=T+dt f.scripts.OnUpdate(f,dt) end
-- kiting pattern: list of {moveFrom, moveTo} windows relative to each shot's reload end
local function runCase(label, moveStart, moveLen)
  -- one shot cycle: shot at T, reload ends at T+D-W, player moves [re+moveStart, re+moveStart+moveLen]
  fire("START_AUTOREPEAT_SPELL")
  fire("PLAYER_SWING", D, 2)        -- "shot" now
  local shotT = T
  local re = shotT + D - W
  local mvA, mvB = re + moveStart, re + moveStart + moveLen
  -- game: attempts at re, re+.5, ... ; succeeds if not moving at attempt and through wind-up
  local attempt = re local realShot
  while not realShot do
    local moving = function(t) return t >= mvA and t < mvB end
    local ok = not moving(attempt) and not moving(attempt + W - 1e-6) and not (mvA > attempt and mvA < attempt + W)
    if ok then realShot = attempt + W else
      -- failure is reported at the attempt (or when movement interrupts the wind-up)
      local failAt = moving(attempt) and attempt or mvA
      attempt = { at = failAt, nxt = failAt + 0.5 }
      local a = attempt attempt = a.nxt
      -- play time forward to the failure and fire the event
      while T < a.at do moving_now = moving(T+dt) _G.moving = moving_now tick() end
      fire("UNIT_SPELLCAST_FAILED_QUIET","player","g",75)
    end
  end
  local predicted
  while T < realShot do _G.moving = (T+dt >= mvA and T+dt < mvB) tick()
    if not predicted and f.SwingStart and T >= f.SwingStart + (f.windup or W) - 1e-9 then predicted = T end end
  _G.moving=false
  fire("PLAYER_SWING", D, 2)
  print(string.format("%-42s real shot %+.2fs after reload end | bar off by %+.3f", label, realShot-re, (predicted or T)-realShot))
  fire("STOP_AUTOREPEAT_SPELL") for i=1,2000 do tick() end
end
runCase("no movement", 99, 0)
runCase("move 0.0-0.3s after reload end", 0.0, 0.3)
runCase("move 0.0-0.7s after reload end", 0.0, 0.7)
runCase("move -0.5..+1.2s (long kite)", -0.5, 1.7)
runCase("interrupt wind-up (move 0.2-0.35)", 0.2, 0.15)
print("OK15")
