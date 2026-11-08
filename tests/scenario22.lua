-- Replay of a real log (518162): spamming an Aimed Shot + !Auto Shot macro.
-- Lone FAILED messages near the end of the reload, then the real wind-up SENT a
-- moment later, used to restart the red fill from empty (stutter). The red part
-- must keep rolling forward between shots: it may speed up or slow down, but
-- never jump backwards.
local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local db=YaHT.db.profile local f=YaHT.mainFrame
db.lock=true YaHT:ApplySettings() f.speed=2.091

-- S = SENT, F = FAILED_QUIET, P = PLAYER_SWING, A = Aimed Shot cast start, E = cast end
local log = {
  {518159.900,"START"}, {518159.990,"S"}, {518160.175,"P"},
  {518162.258,"P"},
  {518162.886,"SFA"}, {518163.010,"SF"}, {518163.282,"SF"}, {518163.544,"SF"},
  {518163.702,"F"}, {518163.972,"S"}, {518164.274,"FF"}, {518164.401,"P"},
  {518164.497,"SF"}, {518164.702,"SFE"}, {518164.833,"SF"}, {518165.059,"SF"},
  {518165.252,"SF"}, {518165.504,"SF"}, {518165.641,"SF"},
  {518165.865,"F"}, {518166.131,"S"}, {518166.299,"SFF"}, {518166.519,"SFFP"},
  {518166.637,"SF"}, {518166.851,"SF"}, {518167.104,"SF"}, {518167.324,"SF"},
  {518167.502,"SF"}, {518167.661,"SF"}, {518167.870,"SF"},
  {518168.136,"F"}, {518168.316,"S"}, {518168.524,"SFF"}, {518168.734,"FFP"},
  {518168.850,"SF"}, {518169.106,"SF"}, {518169.235,"SF"}, {518169.495,"SF"},
  {518169.633,"SF"}, {518169.882,"SF"}, {518170.104,"SF"},
  {518170.211,"F"}, {518170.477,"S"}, {518170.550,"SF"}, {518170.657,"A"}, {518170.893,"P"},
  {518171.120,"SF"}, {518171.343,"SF"}, {518171.575,"SF"}, {518171.669,"SF"},
  {518171.891,"SF"}, {518172.155,"SF"}, {518172.177,"E"},
  {518172.630,"F"}, {518173.163,"FF"}, {518173.361,"F"}, {518173.569,"F"},
  {518173.695,"F"}, {518173.910,"F"},
  {518174.013,"A"}, {518174.065,"S"}, {518174.450,"F"}, {518174.553,"P"},
  {518174.653,"SF"}, {518174.886,"SF"}, {518174.966,"F"}, {518175.228,"E"},
  {518175.973,"F"}, {518176.388,"F"}, {518176.890,"S"}, {518176.978,"FFFF"},
  {518177.184,"FF"}, {518177.295,"PSF"}, {518177.429,"F"},
  {518177.508,"A"}, {518177.937,"E"}, {518177.937,"STOP"},
}

local t, dt = log[1][1], 0.002
local backJumps, worst, shots = 0, 0, 0
local prevFrac, prevShots
local function step(to)
  while t < to - 1e-9 do
    local d = math.min(dt, to - t)
    advance(d) t = t + d
    f.scripts.OnUpdate(f, d)
    if f.SwingStart and f.shooting then
      local frac = f.fillFrac or 0
      if prevFrac and prevShots == shots and frac < prevFrac - 1e-6 then
        backJumps = backJumps + 1
        worst = math.max(worst, prevFrac - frac)
      end
      prevFrac, prevShots = frac, shots
    else
      prevFrac = nil
    end
  end
end

for _, e in ipairs(log) do
  step(e[1])
  if e[2] == "START" then fire("START_AUTOREPEAT_SPELL")
  elseif e[2] == "STOP" then fire("STOP_AUTOREPEAT_SPELL")
  else
    for c in e[2]:gmatch(".") do
      if c == "S" then fire("UNIT_SPELLCAST_SENT","player","t","g",75)
      elseif c == "F" then fire("UNIT_SPELLCAST_FAILED_QUIET","player","g",75)
      elseif c == "P" then fire("PLAYER_SWING", 2.091, 2) shots = shots + 1 prevFrac = nil
      elseif c == "A" then fire("UNIT_SPELLCAST_START","player","g",19434)
      elseif c == "E" then fire("UNIT_SPELLCAST_SUCCEEDED","player","g",19434) fire("UNIT_SPELLCAST_STOP","player","g",19434) end
    end
  end
end

print(string.format("red fill jumped back %d times (worst %.2f of the bar), %d shots", backJumps, worst, shots))
assert(backJumps == 0, "red part jumped backwards while spamming")
print("OK22")
