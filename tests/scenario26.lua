-- Mongoose Bite alert (1.2): the icon pops in when the game says Mongoose Bite is
-- usable (after a dodge), its gold timer drains over 5s, it leaves when the spell
-- is used or the chance ends, and hidden answers never cause errors.
local ev, gev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
for _,f in ipairs(frames) do if f.events.SPELL_UPDATE_USABLE then gev=f end end
assert(gev, "no usability events")
local db=YaHT.db.profile local m=YaHT.mongooseFrame
assert(m, "no Mongoose Bite frame")
db.lock=true YaHT:ApplySettings()

local names = {[1495]="Mongoose Bite"}
local oldName = C_Spell.GetSpellName
C_Spell.GetSpellName = function(id) return names[id] or oldName(id) end
local usable, noMana, calls = false, false, 0
C_Spell.IsSpellUsable = function(s) calls=calls+1 if s ~= "Mongoose Bite" and s ~= 1495 and s ~= 14269 and s ~= 14270 and s ~= 14271 then return false end return usable, noMana end
local cdStart, cdDur = 0, 0
C_Spell.GetSpellCooldown = function() return {startTime=cdStart, duration=cdDur} end
local inCombat = false
function InCombatLockdown() return inCombat end

local dt=0.01
local function run(sec) for k=1,math.floor(sec/dt+0.5) do advance(dt)
  gev.scripts.OnUpdate(gev,dt) if m.shown then m.scripts.OnUpdate(m,dt) end end end
local function fire(e) gev.scripts.OnEvent(gev,e) end

-- out of combat: not polled, nothing shows
run(1)
assert(calls==0 and not m.shown, "works while not fighting")

fire("PLAYER_REGEN_DISABLED")
run(0.5)
assert(not m.shown or m.alpha==0, "shows without a dodge")

-- dodge: Mongoose Bite lights up
-- dodge: Mongoose Bite lights up. A burst of usable events = one check on the next frame
calls=0 usable=true for k=1,25 do fire("SPELL_UPDATE_USABLE") fire("ACTIONBAR_UPDATE_USABLE") end
assert(calls==0, "checked on every event instead of once per frame")
run(0.01)
assert(m.shown and m.proc, "no alert on the proc")
assert(calls==1, "one check should need one question to the game, got "..calls)
run(0.05)
assert(m.icon.w > db.procsize, "icon should pop in a bit big")
run(0.3)
assert(math.abs(m.icon.w-db.procsize)<1e-6 and m.alpha>0.99, "icon should settle at its size")
run(2.15) -- 2.5s into the 5s window
local left=m.timer.width/db.procsize print(string.format("timer at 2.5s: %.0f%%", left*100))
assert(math.abs(left-0.5)<0.03, "gold timer not draining over 5s")
assert(math.abs(m.timer.color[1]-0.85)<1e-6, "timer should be gold")

-- used it: gone (fades out quickly)
usable=false run(0.5)
assert(not m.proc and not m.shown, "alert stays after Mongoose Bite is used")

-- short on mana: still shown, rim turns blue
usable,noMana=false,true run(0.2)
assert(m.proc and m.noMana, "proc with no mana should still show")
run(0.2) assert(math.abs(m.border.color[3]-1.0)<1e-6, "rim should be blue without mana")
noMana=false usable=true run(0.2)
assert(m.proc and not m.noMana, "mana back: gold again")

-- the fight ends while it's up: it leaves when the game says so
fire("PLAYER_REGEN_ENABLED") inCombat=false
usable=false run(0.6)
assert(not m.shown, "alert stuck after the fight")
assert(not gev.shown, "Mongoose Bite checks keep running out of combat")
calls=0 fire("SPELL_UPDATE_USABLE") run(0.5) assert(calls==0, "checks out of combat")

-- hidden answers: quiet, no error
fire("PLAYER_REGEN_DISABLED")
usable=SECRET run(0.5)
assert(not m.proc, "secret value should keep it quiet")
C_Spell.IsSpellUsable=function() error("blocked") end run(0.3)
assert(not m.proc, "blocked call should keep it quiet")
C_Spell.IsSpellUsable=function() return usable, noMana end

-- glow styles: each shows its own effect, others stay hidden
local function anySpark() for i=1,#m.sparks do if m.sparks[i].shown then return true end end return false end
local function proc() usable=true fire("SPELL_UPDATE_USABLE") run(0.4) end
local function done() usable=false run(0.6) assert(not m.shown, "alert stuck") end
for _,st in ipairs({"NONE","HALO","RING","SHINE","SPARKS"}) do
  db.procglow=st YaHT:ApplySettings()
  proc()
  local sawShine=false
  for k=1,20 do run(0.07) sawShine = sawShine or m.shine.shown end
  assert(m.halo.shown == (st=="HALO"), st.." halo wrong")
  assert(m.ring.T.shown == (st=="RING"), st.." ring wrong")
  assert(sawShine == (st=="SHINE"), st.." shine wrong")
  assert(anySpark() == (st=="SPARKS"), st.." sparks wrong")
  done()
  assert(not m.halo.shown and not m.ring.T.shown and not anySpark(), st.." glow left behind")
end
-- sparks really travel around the icon
db.procglow="SPARKS" YaHT:ApplySettings() proc()
local p1={m.sparks[1].point[4],m.sparks[1].point[5]} run(0.3)
assert(p1[1]~=m.sparks[1].point[4] or p1[2]~=m.sparks[1].point[5], "sparks don't move")
done()

-- Proc/Button glows need LibCustomGlow: without it, fall back to the halo
db.procglow="PROC" YaHT:ApplySettings() proc()
assert(m.halo.shown, "no fallback without LibCustomGlow")
done()
local started, stopped = 0, 0
local LCG = LibStub:NewLibrary("LibCustomGlow-1.0", 1)
function LCG.ProcGlow_Start(f, o) assert(f==m.holder and o.color) started=started+1 end
function LCG.ProcGlow_Stop(f) stopped=stopped+1 end
proc()
assert(started==1 and not m.halo.shown, "proc glow not used")
run(1) assert(started==1, "proc glow restarted every frame")
done() assert(stopped>=1, "proc glow not stopped")
db.procglow="HALO" YaHT:ApplySettings()

-- pulse styles
local function sample(field, sec)
  local lo, hi = math.huge, -math.huge
  for k=1,math.floor(sec/0.02) do run(0.02) local v=field() lo=math.min(lo,v) hi=math.max(hi,v) end
  return lo, hi
end
for _,st in ipairs({"NONE","BREATHE","GROW","HEARTBEAT","FLASH"}) do
  db.procpulse=st YaHT:ApplySettings() proc()
  local slo, shi = sample(function() return m.icon.w end, 1.5)
  usable=true
  local alo, ahi = sample(function() return m.icon.alpha end, 1.5)
  local flo, fhi = sample(function() return m.flash.alpha end, 1.0)
  print(string.format("%-9s size %.1f-%.1f  alpha %.2f-%.2f  flash %.2f-%.2f", st, slo, shi, alo, ahi, flo, fhi))
  local grows = shi - slo > 1
  assert(grows == (st=="GROW" or st=="HEARTBEAT"), st.." size pulse wrong")
  assert((ahi - alo > 0.2) == (st=="BREATHE"), st.." breathe wrong")
  assert((fhi > 0.3) == (st=="FLASH"), st.." flash wrong")
  assert(slo >= db.procsize - 1e-6, st.." icon shrank below its size")
  done()
end
db.procpulse="BREATHE"

-- on cooldown when you dodge: grey, sweep, countdown, no glow; pops back when ready
db.procglow="HALO" db.procpulse="GROW" YaHT:ApplySettings()
fire("PLAYER_REGEN_DISABLED") cdStart, cdDur = GetTime()-1, 5 -- 4s of cooldown left
usable=true fire("SPELL_UPDATE_USABLE") run(0.3)
assert(m.proc and m.drawnCD and m.cdShade.shown and m.cdText.shown, "no cooldown look while on cooldown")
assert(m.cdText.txt=="4", "countdown should say 4, says "..tostring(m.cdText.txt))
assert(not m.halo.shown, "glow says 'press it' while still on cooldown")
run(1.5) assert(m.cdText.txt=="2.2" or m.cdText.txt=="2.3", "tenths under 3s, got "..tostring(m.cdText.txt))
local sz=m.icon.w run(0.3) assert(m.icon.w==sz, "pulsing while on cooldown")
cdStart, cdDur = 0, 0 run(2.2) -- cooldown over during the chance
assert(not m.drawnCD and not m.cdShade.shown and not m.cdText.shown, "cooldown look stuck after it's ready")
assert(m.readyAt, "no 'ready' pop when it comes off cooldown")
assert(m.halo.shown, "glow should come back once it's ready")
usable=false run(0.6)
-- the setting off: no cooldown look
db.mongoosecooldown=false cdStart, cdDur = GetTime(), 5
usable=true fire("SPELL_UPDATE_USABLE") run(0.3)
assert(not m.cdShade.shown, "cooldown shown although switched off")
usable=false run(0.6) db.mongoosecooldown=true cdStart, cdDur = 0, 0
-- the global cooldown doesn't count
cdStart, cdDur = GetTime(), 1.5 usable=true fire("SPELL_UPDATE_USABLE") run(0.3)
assert(not m.cdShade.shown, "global cooldown treated as Mongoose Bite's cooldown")
-- hidden cooldown: no cooldown look, no error
C_Spell.GetSpellCooldown = function() return SECRET end run(0.3)
assert(not m.cdShade.shown and m.proc, "secret cooldown should just be ignored")
C_Spell.GetSpellCooldown = function() return {startTime=cdStart, duration=cdDur} end
usable=false run(0.6) cdStart, cdDur = 0, 0
db.procglow="HALO" db.procpulse="BREATHE" YaHT:ApplySettings()

-- positions
for _,pos in ipairs({"ABOVE","LEFT","RIGHT"}) do
  db.mongoosepos=pos YaHT:ApplySettings()
  local want = ({ABOVE="BOTTOM", LEFT="RIGHT", RIGHT="LEFT"})[pos]
  assert(m.point[1]==want and m.point[2]==YaHT.mainFrame, "position "..pos.." anchored wrong")
end

-- switched off: no alert
db.mongoose=false YaHT:ApplySettings()
usable=true fire("SPELL_UPDATE_USABLE") run(0.3)
assert(not m.shown and not m.proc, "shows although switched off")
db.mongoose=true usable=false

-- unlocked: preview loops so you can place it
db.lock=false YaHT:ApplySettings() run(0.5)
assert(m.shown and m.alpha>0.9, "no preview while unlocked")
-- "Preview all alerts": Mongoose Bite's own check (it isn't usable) must not take the preview down
db.lock = true YaHT:ApplySettings() usable = false fire("SPELL_UPDATE_USABLE") run(0.5)
local mf = YaHT.mongooseFrame
assert(not mf.proc, "setup: no Mongoose Bite chance")
YaHT:PreviewAlerts()
fire("SPELL_UPDATE_USABLE") run(0.6)
assert(mf.proc and mf.shown and mf.previewUntil, "Mongoose Bite dropped out of Preview all alerts")
run(7) assert(not mf.proc and not mf.previewUntil, "the preview should end by itself")
print("OK26")
