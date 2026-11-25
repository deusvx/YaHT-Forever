-- Quick Shots on the very first shot after logging in (or a reload). The game hides your buffs in
-- a fight, so Quick Shots is told from your shot speed, and that needs your normal speed. It used
-- to be learned from the first shot: when that one was already a fast one, the fast speed was taken
-- for normal and the icon never came, for the whole session. Now the normal speed is read from the
-- game before the fight, and the last one learned is kept with the character.
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local NORMAL = 2.589
local inFight = false
function UnitRangedDamage() if inFight then return SECRET end return NORMAL end
function UnitAffectingCombat() return inFight end
C_UnitAuras = {GetPlayerAuraBySpellID = function() return nil end, GetAuraDataBySpellName = function() return nil end}
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db=YaHT.db.profile local q=YaHT.quickShotsFrame local w=YaHT.quickShotsWatch
local speed = YaHT.quickSpeed
db.lock=true YaHT:ApplySettings()
local dt=0.01
local function run(sec) for k=1,math.floor(sec/dt+0.5) do advance(dt)
  if w.shown then w.scripts.OnUpdate(w,dt) end
  if q.shown then q.scripts.OnUpdate(q,dt) end end end
local function swing(d) w.scripts.OnEvent(w,"PLAYER_SWING", d, 2) run(0.05) end

-- 1) the fight starts (speed still readable at that moment), and the first shot is already fast
w.scripts.OnEvent(w,"PLAYER_REGEN_DISABLED") inFight = true
assert(speed.seed == NORMAL, "the normal speed should be read from the game before the fight")
swing(NORMAL / 1.3)
assert(speed.base == NORMAL, "a fast first shot must not be taken for the normal speed")
assert(q.proc, "Quick Shots on the first shot didn't show")
run(13) assert(not q.proc, "it should end after its 12 seconds")

-- 2) the game would not say before the fight, but the character's last learned speed is kept
speed.base, speed.seed, speed.fast, speed.lastShot = nil, nil, false, nil
YaHT.db.char.quickBase = NORMAL
swing(NORMAL / 1.3)
assert(speed.base == NORMAL and q.proc, "the kept speed should serve for the first shot")
run(13)

-- 3) nothing known and the first shot fast: the next normal shot puts it right, the one after shows
speed.base, speed.seed, speed.fast, speed.lastShot = nil, nil, false, nil
YaHT.db.char.quickBase = nil
swing(NORMAL / 1.3) assert(not q.proc)
run(2) swing(NORMAL)
assert(math.abs(speed.base - NORMAL) < 0.001, "a shot slower by Quick Shots' share should correct the normal speed")
run(2.5) swing(NORMAL / 1.3)
assert(q.proc, "after the correction Quick Shots should show again")
run(13)

-- 4) a different bow than the kept speed: the kept one is not believed, and nothing shows by mistake
speed.base, speed.seed, speed.fast, speed.lastShot = nil, nil, false, nil
YaHT.db.char.quickBase = 3.2
swing(2.1) run(2.1) swing(2.1)
assert(speed.base == 2.1 and not q.proc, "a new weapon's speed must not be read as Quick Shots")

-- 5) the normal speed is not read while a speed-up is known to be on
inFight = false NORMAL = 1.99
speed.fast = true w.scripts.OnEvent(w,"UNIT_AURA","player")
assert(speed.seed ~= 1.99, "the speed must not be read while Quick Shots is on")
print("OK55")
