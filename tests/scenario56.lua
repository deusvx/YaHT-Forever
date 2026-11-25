-- Quick Shots found as a buff after a fight. In a fight the game hides your buffs; when the fight
-- ends they can be read again. YaHT used to look only at your next cast or buff change, so a Quick
-- Shots from the last shot of a fight popped up (with its sound) on whatever you did next, e.g.
-- Mend Pet. And the same proc, read first by shot speed and then as a buff, sounded twice.
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local NORMAL = 2.589
local inFight, buffEnds = false, nil
function UnitRangedDamage() if inFight then return SECRET end return NORMAL end
function UnitAffectingCombat() return inFight end
local function buff()
  if inFight then return SECRET end -- (a fight hides your buffs)
  if not buffEnds or GetTime() >= buffEnds then return nil end
  return {spellId = 6150, name = "Quick Shots", expirationTime = buffEnds, duration = 12}
end
C_UnitAuras = {GetPlayerAuraBySpellID = function() return buff() end, GetAuraDataBySpellName = function() return buff() end}
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db=YaHT.db.profile local q=YaHT.quickShotsFrame local w=YaHT.quickShotsWatch
local speed = YaHT.quickSpeed
db.lock=true db.quickshotsiconsound=true YaHT:ApplySettings()
local dt=0.01
local function run(sec) for k=1,math.floor(sec/dt+0.5) do advance(dt)
  if w.shown then w.scripts.OnUpdate(w,dt) end
  if q.shown then q.scripts.OnUpdate(q,dt) end end end
local function swing(d) w.scripts.OnEvent(w,"PLAYER_SWING", d, 2) run(0.05) end
local function sounds() local n=0 for _,l in ipairs(YaHT.db.global.record or {}) do
  if l:find("QuickShots popped up",1,true) then n=n+1 end end return n end
local function fight(on) inFight = on w.scripts.OnEvent(w, on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED") end

-- 1) it procs on the last shot of a fight; the fight ends a second later: it shows at once, with its sound
fight(true) swing(NORMAL) run(2.5) swing(NORMAL)
buffEnds = GetTime() + 12
run(1) assert(not q.proc)
fight(false) run(0.3)
assert(q.proc, "Quick Shots should show when the fight ends, not at your next cast")
assert(sounds() == 1, "it should sound once, got "..sounds())
-- 2) the next fight starts and hides the buff: the icon carries on, without a second sound
fight(true) run(0.5)
assert(q.proc, "the icon should carry on into the next fight")
fight(false) run(0.5)
assert(q.proc and sounds() == 1, "the same proc must not sound again, got "..sounds())
run(13) assert(not q.proc, "it should end with the buff")

-- 3) found late (8 seconds in): the icon shows what is left, without the sound
speed.fast = false
fight(true) run(1)
buffEnds = GetTime() + 12
run(8) fight(false) run(0.3)
assert(q.proc, "a late find should still show")
assert(sounds() == 1, "a late find must be quiet, got "..sounds())
run(6) assert(not q.proc)

-- 4) seen by shot speed in the fight, then as a buff after it: one proc, one sound
speed.fast = false buffEnds = nil
fight(true) swing(NORMAL) run(2.5) swing(NORMAL)
buffEnds = GetTime() + 12
run(2) swing(NORMAL / 1.3)
assert(q.proc and sounds() == 2, "the fast shot should show it, got "..sounds())
run(1) fight(false) run(0.5)
assert(q.proc and sounds() == 2, "reading it as a buff afterwards must not sound again, got "..sounds())
-- 5) a real new proc while it is up (a later start, seen as a buff) does sound
run(3) buffEnds = GetTime() + 12
w.scripts.OnEvent(w,"UNIT_AURA","player") run(0.3)
assert(sounds() == 3, "a new proc should sound again, got "..sounds())
print("OK56")
