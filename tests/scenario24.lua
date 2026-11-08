-- Melee swing line (1.1): hidden at range, fades in while meleeing, fills with
-- the main-hand swing, turns gold while Raptor Strike is queued, glints on each
-- swing, fades out after you stop, and never touches the Auto Shot bar.
local ev, mev
for _,f in ipairs(frames) do
  if f.events.PLAYER_LOGIN then ev=f end
end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
for _,f in ipairs(frames) do if f.events.PLAYER_ENTER_COMBAT then mev=f end end
local function mfire(e,...) mev.scripts.OnEvent(mev,e,...) end
local db=YaHT.db.profile local f=YaHT.mainFrame local m=YaHT.meleeFrame
db.lock=true YaHT:ApplySettings()
assert(m, "no melee frame")
local dt=0.01
local function run(sec) for k=1,math.floor(sec/dt+0.5) do advance(dt)
  f.scripts.OnUpdate(f,dt) if m.shown then m.scripts.OnUpdate(m,dt) end end end

local queued = false
C_Spell.IsCurrentSpell = function(id) return queued and id == 2973 end

run(0.5)
print("at range, before melee: shown", m.shown, "alpha", m.alpha)
assert(not m.shown or m.alpha == 0, "melee line visible at range")

-- melee auto-attack on, first swing
mfire("PLAYER_ENTER_COMBAT") mfire("PLAYER_SWING", 2.8, 0)
run(0.3)
print(string.format("fading in: alpha %.2f", m.alpha))
assert(m.alpha > 0.9, "line didn't fade in")
run(0.1)
assert(m.glint.shown == false, "glint should be done after 0.4s")
run(1.0) -- 1.4s into a 2.8s swing
local half = m.fill.width / db.width
print(string.format("1.4s into a 2.8s swing: line %.0f%% full", half*100))
assert(math.abs(half - 0.5) < 0.03, "melee fill not following the swing")

-- Raptor Strike queued -> gold
queued = true run(0.15)
print("raptor queued color:", m.fill.color[1], m.fill.color[2], m.fill.color[3])
assert(math.abs(m.fill.color[1] - db.meleeraptorcolor.r) < 1e-6, "not gold while Raptor Strike is queued")
queued = false mfire("PLAYER_SWING", 2.8, 0) run(0.15)
assert(math.abs(m.fill.color[1] - db.meleecolor.r) < 1e-6, "still gold after the swing")

-- a ranged swing must not touch the melee line, and melee swings not the Auto Shot bar
local before = m.swingStart
fire("PLAYER_SWING", 2.091, 2)
assert(m.swingStart == before, "ranged swing moved the melee line")
local lastshot = f.lastshot
fire("PLAYER_SWING", 2.8, 0) mfire("PLAYER_SWING", 2.8, 0)
assert(f.lastshot == lastshot, "a melee swing moved the Auto Shot bar")

-- stop meleeing: fades out and goes fully idle (hidden, no OnUpdate work)
mfire("PLAYER_LEAVE_COMBAT")
run(2.8 + 0.75 + 1.0)
print("after leaving melee: shown", m.shown, string.format("alpha %.2f", m.alpha))
assert(not m.shown, "melee line didn't go idle")

-- turned off in options: never shows
db.melee=false YaHT:ApplySettings()
mfire("PLAYER_ENTER_COMBAT") mfire("PLAYER_SWING", 2.8, 0) run(0.5)
assert(not m.shown, "shows although switched off")
db.melee=true

-- unlocked: preview runs even at range
db.lock=false YaHT:ApplySettings() run(0.5)
print(string.format("unlocked preview: shown %s alpha %.2f", tostring(m.shown), m.alpha))
assert(m.shown and m.alpha > 0.9, "no preview while unlocked")
print("OK24")
