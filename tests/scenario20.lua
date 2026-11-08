-- Replay of a real log: Auto Shot running while spamming an Aimed Shot macro
-- (Aimed Shot + !Auto Shot). Every press during the reload made the game send
-- SENT + FAILED together (refused). The bar must NOT start the red wind-up
-- early for those; real wind-ups (a SENT that isn't refused) still re-sync it.
local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local db=YaHT.db.profile local f=YaHT.mainFrame
db.lock=true YaHT:ApplySettings() f.speed=2.091

local T0 = 481758.283
-- {log time, events}: S = SENT, F = FAILED_QUIET, P = PLAYER_SWING
local log = {
  {481758.283,"START"}, {481758.415,"S"}, {481758.886,"P"},
  {481759.142,"SF"}, {481759.278,"SF"}, {481759.468,"SF"}, {481759.714,"SF"},
  {481759.812,"SF"}, {481760.111,"SF"}, {481760.273,"SF"}, {481760.411,"SF"},
  {481760.614,"S"}, {481760.830,"SFF"}, {481761.087,"P"},
  {481762.709,"F"}, {481762.861,"SF"}, {481763.071,"S"}, {481763.244,"SFF"},
  {481763.367,"SFF"}, {481763.478,"P"},
  {481763.615,"SF"}, {481763.766,"SF"}, {481763.917,"SF"}, {481764.170,"SF"},
  {481764.329,"SF"}, {481764.576,"SF"}, {481764.714,"SF"}, {481764.924,"SF"},
  {481765.122,"S"}, {481765.232,"SFF"}, {481765.528,"SFFP"},
  {481765.718,"SF"}, {481765.829,"SF"}, {481766.033,"SF"}, {481766.275,"SF"},
  {481766.439,"SF"}, {481766.578,"SF"}, {481766.863,"SF"}, {481767.000,"SF"},
  {481767.274,"S"}, {481767.585,"FF"}, {481767.724,"P"},
  {481767.887,"SF"}, {481767.980,"SF"}, {481768.218,"STOP"},
}

local t = T0
local worstEarly, checks = 0, {}
local measuring = false -- only once a shot has gone out (the first SENT is always real)
local dt = 0.002
local function step(to)
  while t < to - 1e-9 do
    local d = math.min(dt, to - t)
    advance(d) t = t + d
    f.scripts.OnUpdate(f, d)
    if measuring and f.shooting and f.SwingStart and f.lastshot and f.swingtime then
      local early = f.SwingStart - (f.lastshot + f.swingtime)
      if early < worstEarly then worstEarly = early end
    end
  end
end

for _, e in ipairs(log) do
  step(e[1])
  local kind = e[2]
  if kind == "START" then fire("START_AUTOREPEAT_SPELL")
  elseif kind == "STOP" then fire("UNIT_SPELLCAST_FAILED_QUIET","player","g",75) fire("STOP_AUTOREPEAT_SPELL")
  else
    for c in kind:gmatch(".") do
      if c == "S" then fire("UNIT_SPELLCAST_SENT","player","t","g",75)
      elseif c == "F" then fire("UNIT_SPELLCAST_FAILED_QUIET","player","g",75)
      elseif c == "P" then fire("PLAYER_SWING", 2.091, 2) measuring = true end
    end
  end
  -- right after a real (not refused) SENT, the wind-up must start there
  if e[1] == 481760.614 or e[1] == 481763.071 or e[1] == 481765.122 then
    local at = e[1]
    step(at + 0.06)
    checks[#checks+1] = f.SwingStart and math.abs(f.SwingStart - (GetTime() - 0.06)) < 0.003
  end
end

print(string.format("worst early wind-up start vs reload end: %+.3fs", worstEarly))
local allSynced = true for _, ok in ipairs(checks) do allSynced = allSynced and ok end
print("real wind-ups re-synced:", allSynced, #checks)
assert(worstEarly > -0.3, "bar went red too early on refused key presses")
assert(allSynced and #checks == 3, "a real wind-up start was not applied")
print("OK20")
