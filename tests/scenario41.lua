-- Hawk circles (1.4): your Summon Hawk hawks as round icons at the top left of the bar, each with a
-- ring that runs down over its 18 seconds. Up to two; a third cast replaces the older one. Timed from
-- your own cast; the game's summon slots are used when it lists the hawks there.
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end

-- the game: Summon Hawk in two ranks (one known by its number, one only by its name), and summon slots
local names = {[1293241] = "Summon Hawk", [1293300] = "Summon Hawk", [3044] = "Arcane Shot"}
local oldName = C_Spell.GetSpellName
C_Spell.GetSpellName = function(id) return names[id] or oldName(id) end
C_Spell.GetSpellTexture = function(id) if names[id] == "Summon Hawk" then return "hawk-icon" end end
local totems, hideSlots = {}, false
MAX_TOTEMS = 4
function GetTotemInfo(slot)
  if hideSlots then return SECRET, SECRET, SECRET, SECRET, SECRET end
  local t = totems[slot]
  if not t then return false, "", 0, 0, nil end
  return true, t.name, t.start, t.dur, t.icon
end

ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db = YaHT.db.profile
-- (the polished look is off to start with; most of this is about it, so it is switched on here)
assert(db.hawkpolish == false, "the polished look should be off to start with")
db.hawkpolish = true YaHT:ApplySettings()
local h, w, slots = YaHT.hawkFrame, YaHT.hawkWatch, YaHT.hawkSlots
assert(h and w and slots, "no hawk circles")
local c1, c2 = h.circles[1], h.circles[2]
local bar = YaHT.mainFrame

local dt = 0.05
local function run(sec) for k = 1, math.floor(sec/dt + 0.5) do advance(dt)
  if w.shown then w.scripts.OnUpdate(w, dt) end end end
local function fire(e, ...) w.scripts.OnEvent(w, e, ...) end
local function cast(id) fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-x", id or 1293241) end
local function red(c) return c.cd.swipe ~= nil and c.cd.swipe[2] < 0.5 end
local function near(x, y) return math.abs(x - y) < 1e-6 end

-- a fresh install (bar unlocked): two sample circles stand at the top left of the bar, so you see them
assert(h.shown and c1.shown and c2.shown, "no sample circles while unlocked")
assert(h.point[1] == "BOTTOMLEFT" and h.point[2] == bar and h.point[3] == "TOPLEFT", "not at the top left of the bar")
assert(c1.num.txt == "14" and c2.num.txt == "5", "sample numbers: "..tostring(c1.num.txt).." "..tostring(c2.num.txt))
assert(c1.full.shown and not c1.cd.shown, "a sample should stand still")
assert(not red(c1) and red(c2), "under 6 seconds should be red, above it gold")
assert(c1.icon.tex == "hawk-icon", "not the Summon Hawk icon: "..tostring(c1.icon.tex))
assert(not w.shown, "nothing to time: should be asleep")
assert(h.mouse == false and not h.dragHint.shown, "attached to the bar: not draggable")

-- locked and no hawk out: nothing on screen, nothing running
db.lock = true YaHT:ApplySettings() run(0.2)
assert(not h.shown and not w.shown, "should be away and asleep with no hawk out")

-- the greyed-out free circle is off unless you switch it on; the next checks are about it
assert(db.hawkempty == false, "the free circle should be off by default")
db.hawkempty = true YaHT:ApplySettings()
-- you cast Summon Hawk: the first circle runs for 18 seconds, the second waits dimmed
local t1 = GetTime()
cast() run(0.2)
assert(h.shown and c1.shown and c1.cd.shown and not c1.full.shown, "the first hawk has no running circle")
assert(c1.cd.cooldown and near(c1.cd.cooldown[1], t1) and c1.cd.cooldown[2] == 18, "the ring isn't timed from the cast for 18s")
assert(c1.num.txt == "18" and not red(c1), "first hawk: "..tostring(c1.num.txt))
assert(c2.shown and c2.icon.alpha == 0.3 and c2.icon.desat == true and not c2.cd.shown and c2.num.txt == "", "the free circle should be dim and empty")

-- the polish: a glow in the ring's colour around a hawk, none around the free circle, a gloss and fine edge lines
assert(c1.halo.shown and c1.halo.color[2] > 0.5 and not c2.halo.shown, "the glow belongs to a hawk that is out")
assert(c1.gloss and c1.line and c1.shadow, "the circle is missing part of its look")

-- "Polished look" switched off: the standard look, a plain flat ring and nothing else
db.hawkpolish = false YaHT:ApplySettings() run(0.2)
assert(not c1.halo.shown and not c1.gloss.shown and not c1.line.shown and not c1.shadow.shown, "the plain look should have no glow, gloss, edge lines or shadow")
assert(c1.track.tex:find("RingFlat", 1, true) and c1.full.tex:find("RingFlat", 1, true) and c1.cd.shown, "the plain look should use the flat ring")
db.hawkpolish = true YaHT:ApplySettings() run(0.2)
assert(c1.halo.shown and c1.gloss.shown and c1.line.shown and not c1.track.tex:find("RingFlat", 1, true), "the polished look should come back")

-- other spells, other units and a hidden spell change nothing
cast(3044) fire("UNIT_SPELLCAST_SUCCEEDED", "pet", "cast-y", 1293241) fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-z", SECRET) run(0.1)
assert(slots[1] and not slots[2], "something that isn't your Summon Hawk counted as a hawk")

-- six seconds later a second hawk, cast in a rank known only by its name
run(5.7)
local t2 = GetTime()
cast(1293300) run(0.2)
assert(slots[2] and near(c2.cd.cooldown[1], t2) and c2.icon.alpha == 1 and c2.icon.desat == false, "the second hawk didn't take the second circle")
assert(c1.num.txt == "12" and c2.num.txt == "18", "numbers: "..c1.num.txt.." "..c2.num.txt)

-- the first hawk goes under 6 seconds: red. The second stays gold.
run(6.2)
assert(red(c1) and not red(c2) and c1.num.txt == "6", "first hawk should be red under 6 seconds: "..c1.num.txt)
assert(c1.halo.color[2] < 0.5 and c1.pulse.playing and not c2.pulse.playing, "a red ring's glow should turn red and breathe")

-- a third cast with two out: the older hawk's circle starts again, the other is untouched
local t3 = GetTime()
cast() run(0.2)
assert(near(slots[1].start, t3) and near(c1.cd.cooldown[1], t3) and not red(c1), "the older hawk wasn't replaced in place")
assert(near(slots[2].start, t2), "the newer hawk was disturbed")

-- they run out: first the one from the second cast, then the last. Then nothing shows and nothing runs.
run(12)
assert(slots[1] and not slots[2] and c2.icon.alpha == 0.3, "the second hawk should have run out")
run(6.5)
assert(not slots[1] and not h.shown and not w.shown, "should be away and asleep once every hawk is gone")

-- one circle with a count: the hawk that ends first, and how many are out
db.hawkmode = "COUNT" YaHT:ApplySettings()
local a1 = GetTime()
cast() run(6)
local a2 = GetTime()
cast() run(0.2)
assert(h.shown and c1.shown and not c2.shown and h.badge.shown and h.count.txt == "2", "count layout: "..tostring(h.count.txt))
assert(near(c1.cd.cooldown[1], a1), "the one circle should follow the hawk that ends first")
run(12.5)
assert(h.count.txt == "1" and near(c1.cd.cooldown[1], a2), "after the first ran out the circle should follow the other")
run(6)
assert(not h.shown, "count layout should go away with the last hawk")
db.hawkmode = "EACH" YaHT:ApplySettings()
assert(not h.badge.shown, "the count belongs to the one-circle layout only")

-- settings: no numbers, no red, the other corner, anywhere
cast() run(13.3)
assert(red(c1) and c1.num.txt == "5", "setup for the settings checks")
db.hawknumbers = false YaHT:ApplySettings() run(0.2)
assert(c1.num.txt == "", "numbers switched off still show")
db.hawkwarn = 0 YaHT:ApplySettings() run(0.2)
assert(not red(c1), "red switched off still shows")
db.hawknumbers, db.hawkwarn = true, 6
-- the seconds can sit under the circle (as they start out), in the middle of it, or above it
YaHT:ApplySettings() run(0.2)
assert(c1.num.point[1] == "TOP" and c1.num.point[3] == "BOTTOM" and h.h == 26 + 13 and c1.point[5] == 0, "numbers should start under the circle")
db.hawknumpos = "MIDDLE" YaHT:ApplySettings() run(0.2)
assert(c1.num.point[1] == "CENTER" and h.h == 26 and c1.num.txt ~= "", "numbers in the middle: over the icon, and no extra row")
db.hawknumpos = "TOP" YaHT:ApplySettings() run(0.2)
assert(c1.num.point[1] == "BOTTOM" and c1.num.point[3] == "TOP" and h.h == 26 + 13 and c1.point[5] == -13, "numbers above: the circles stay on the bar")
db.hawknumpos = "BOTTOM" YaHT:ApplySettings()
db.hawkpos = "TOPRIGHT" YaHT:ApplySettings()
assert(h.point[1] == "BOTTOMRIGHT" and h.point[2] == bar and h.point[3] == "TOPRIGHT", "top right of the bar")
db.hawkpos = "FREE" YaHT:ApplySettings()
assert(h.mouse == false, "locked: not draggable")
db.lock = false YaHT:ApplySettings()
assert(h.mouse == true and h.dragHint.shown, "unlocked and set to anywhere: should be draggable")
h.scripts.OnDragStop(h)
assert(db.hawkpoint == "CENTER" and db.hawkx == 10 and db.hawky == 20, "dragged spot not saved")
YaHT:ApplySettings()
assert(h.point[1] == "CENTER" and h.point[2] == UIParent and h.point[4] == 10, "the saved spot isn't used")
db.lock, db.hawkpos = true, "TOPLEFT" YaHT:ApplySettings()
run(6)

-- with the free circle off (as it starts out) only the hawks that are out show, from the left
db.hawkempty = false YaHT:ApplySettings()
cast() run(0.2)
assert(c1.shown and c1.cd.shown and not c2.shown, "with the free circle off, one hawk should show one circle")
run(5.8)
local second = GetTime()
cast() run(0.2)
assert(c1.shown and c2.shown and near(c2.cd.cooldown[1], second), "the second hawk should show beside the first")
run(12.2)
assert(c1.shown and not c2.shown and near(c1.cd.cooldown[1], second), "the hawk that is left should move to the first place")
run(6)
assert(not h.shown, "nothing should show once they are gone")
db.hawkempty = false YaHT:ApplySettings()

-- you die: the hawks are gone
cast() run(1)
fire("PLAYER_DEAD") run(0.2)
assert(not slots[1] and not h.shown, "hawks should be cleared when you die")

-- "Preview all alerts": two samples with running rings for a few seconds, then away
YaHT:PreviewHawks(6) run(0.2)
assert(h.shown and c1.cd.shown and c2.cd.shown and c1.num.txt == "14" and red(c2), "preview should show two running samples")
run(6.2)
assert(not h.shown and not w.shown, "the preview should end by itself")

-- switched off: nothing, whatever happens
db.hawk = false YaHT:ApplySettings()
cast() run(0.3)
assert(not h.shown, "switched off but showing")
YaHT:PreviewHawks(6) run(0.2)
assert(not h.shown, "a preview of something switched off")
db.hawk = true YaHT:ApplySettings()
run(19)

-- The game's summon slots. While it has never listed a hawk there, an empty slot proves nothing.
local before = YaHT.errorCount or 0
cast() run(2)
fire("PLAYER_TOTEM_UPDATE") run(0.2)
assert(slots[1], "an empty summon slot ended a hawk although the game never listed one")
-- hidden slot values are never touched
hideSlots = true
fire("PLAYER_TOTEM_UPDATE") run(0.2)
assert(slots[1] and (YaHT.errorCount or 0) == before, "hidden summon slots caused trouble")
hideSlots = false
run(18)
-- Now the game lists the hawk: its own start and length are used...
local g = GetTime()
totems[2] = {name = "Hawk", start = g + 0.4, dur = 16, icon = "hawk-icon"}
cast() run(0.8)
assert(slots[1] and near(slots[1].start, g + 0.4) and slots[1].dur == 16, "the game's own timing of the hawk wasn't used")
assert(near(c1.cd.cooldown[1], g + 0.4) and c1.cd.cooldown[2] == 16, "the ring didn't follow the game's timing")
local seen = false
for _, line in ipairs(YaHT.db.global.record or {}) do if line:find("[hawk]", 1, true) and line:find("summon slots", 1, true) then seen = true end end
assert(seen, "the record should say what the summon slots showed")
-- ...and when it stops listing it, the hawk has died early
run(2)
totems[2] = nil
fire("PLAYER_TOTEM_UPDATE") run(0.2)
assert(not slots[1] and not h.shown, "a hawk the game no longer lists should be gone")

-- /yaht hawk says what YaHT sees
local line
local add = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(_, m) if m:find("Hawks:", 1, true) then line = m end end
SlashCmdList["YAHT"]("hawk")
DEFAULT_CHAT_FRAME.AddMessage = add
assert(line and line:find("1: none", 1, true) and line:find("summon slots: yes", 1, true), "/yaht hawk: "..tostring(line))
assert((YaHT.errorCount or 0) == before, "YaHT reported a problem")
print("OK41")
