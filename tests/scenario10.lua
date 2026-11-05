local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local R = LibStub("AceConfigRegistry-3.0")
R:ValidateOptionsTable(R:GetOptionsTable("YaHT")("dialog","AceConfigDialog-3.0"), "YaHT")
local db=YaHT.db.profile local f=YaHT.mainFrame
db.lock=true YaHT:ApplySettings()
local D, LAG, W = 2.24, 0.12, 0.4   -- swing time, hidden extra delay per cycle, wind-up (2.8 base)
local dt=0.005
local function tick() advance(dt) f.scripts.OnUpdate(f,dt) end
local function run(withStartEvent, label)
  YaHT.calib=nil YaHT.calibSamples=nil
  fire("START_AUTOREPEAT_SPELL")
  local t=0 local nextShot=W  -- first shot: wind-up right away
  local castStart = 0
  local errs={}
  for shot=1,10 do
    -- run until the real shot moment, noting when the bar says "shot" (wind-up done)
    local predicted
    while t < nextShot - 1e-9 do
      if withStartEvent and math.abs(t - castStart) < dt/2 then fire("UNIT_SPELLCAST_START","player","g",75) end
      tick() t=t+dt
      if not predicted and f.SwingStart and (GetTime()-f.SwingStart) >= (f.windup or W) - 1e-9 then predicted=t end
    end
    fire("PLAYER_SWING", D, 2)
    table.insert(errs, string.format("%+.2f", (predicted or t) - t))
    castStart = t + D + LAG - W     -- real next wind-up start
    nextShot = t + D + LAG          -- real next shot
  end
  print(label, "bar 'shot' moment minus real shot, per shot:", table.concat(errs," "))
  print("   learned delay", string.format("%.3f", YaHT.calib or 0), "samples", YaHT.calibSamples)
  fire("STOP_AUTOREPEAT_SPELL") for i=1,800 do tick() end
end
db.autocorrect=false run(false, "OFF (old behaviour):")
db.autocorrect=true  run(false, "ON, calibration only:")
db.autocorrect=true  run(true,  "ON, + cast-start events:")
print("OK10")
