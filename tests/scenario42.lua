-- Square hawks and the polished look (1.4). The hawks can be squares instead of circles: then each is
-- a proc icon like Rapid Fire's (rim or polished frame, gold timer line, glow, pulse, sound; the shared
-- look or its own), and they can stand in the row of the other icons. Every square icon (proc icons,
-- aspect badge, square hawks) has the polished look as a setting.
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end

local names = {[1293241] = "Summon Hawk", [3045] = "Rapid Fire"}
local oldName = C_Spell.GetSpellName
C_Spell.GetSpellName = function(id) return names[id] or oldName(id) end
C_Spell.GetSpellTexture = function(id) if names[id] == "Summon Hawk" then return "hawk-icon" end return "icon"..tostring(id) end

ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db = YaHT.db.profile
local h, w, slots, icons = YaHT.hawkFrame, YaHT.hawkWatch, YaHT.hawkSlots, YaHT.hawkIcons
assert(h and w and slots and icons and icons[1] and icons[2], "no square hawks")
local s1, s2 = icons[1].frame, icons[2].frame
local c1, c2 = h.circles[1], h.circles[2]
local bar, r, badge = YaHT.mainFrame, YaHT.rapidFireFrame, YaHT.aspectFrame
assert(r and badge, "no Rapid Fire icon / aspect badge")
local before = YaHT.errorCount or 0

local dt = 0.05
local function run(sec) for k = 1, math.floor(sec/dt + 0.5) do advance(dt)
  if w.shown then w.scripts.OnUpdate(w, dt) end
  for _, f in ipairs({s1, s2, r}) do if f.shown then f.scripts.OnUpdate(f, dt) end end end end
local function cast() w.scripts.OnEvent(w, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-x", 1293241) end
local function near(x, y) return math.abs(x - y) < 1e-6 end
local function red(f) return f.polish.frame.color[2] < 0.5 and f.timer.color[2] < 0.5 end

-- as it starts out: circles, and no square anywhere
assert(db.hawkshape == "CIRCLE", "the hawks should start out as circles")
assert(c1.shown and not s1.shown and not s2.shown, "circles are the shape: no squares should show")

-- the polished look is off to start with, everywhere: the standard look with its flat rim
for _, key in ipairs(YaHT.polishKeys) do assert(db[key] == false, key.." should be off to start with") end
assert(r.border.shown and not r.polish.frame.shown and badge.rim.shown and not badge.polish.frame.shown, "the standard look should be what you start with")
assert(not c1.halo.shown and not c1.gloss.shown and c1.track.tex:find("RingFlat", 1, true), "the hawk circles should start in the standard look")
-- one switch (Home page, Alerts page) turns it on for every icon at once, and off again
local all = YaHT.optionsTable.args.alerts.args.polishall
assert(all and all.get() == false, "no switch for all polish, or it is on")
all.set({"alerts", "polishall"}, true)
for _, key in ipairs(YaHT.polishKeys) do assert(db[key] == true, key.." wasn't switched on by the one switch") end
assert(all.get() == true and c1.gloss.shown and not c1.track.tex:find("RingFlat", 1, true), "the one switch should polish the hawk circles too")
db.aspectpolish = false
assert(all.get() == false, "with one icon back on the standard look the switch should read off")
all.set({"alerts", "polishall"}, false)
assert(not db.procpolish and not db.hawkpolish and r.border.shown and not r.polish.frame.shown, "the one switch should bring back the standard look everywhere")
all.set({"alerts", "polishall"}, true)
-- polished: on every square icon; each page's own switch brings back the flat rim there
assert(db.procpolish and db.aspectpolish, "the one switch should have switched the polished look on")
assert(r.polish.frame.shown and r.polish.gloss.shown and r.polish.shadow.shown and r.polish.line.shown and not r.border.shown, "Rapid Fire's icon should have the polished look")
assert(r.polish.frame.tex:find("SquareRing", 1, true) and r.polish.frame.w == db.procsize + 2, "the frame should stand where the rim does")
assert(badge.polish.frame.shown and not badge.rim.shown, "the aspect badge should have the polished look")
db.procpolish = false YaHT:ApplySettings()
assert(r.border.shown and not r.polish.frame.shown and not r.polish.gloss.shown and not r.polish.shadow.shown, "switched off: the standard look with its flat rim")
assert(badge.polish.frame.shown, "the aspect badge has its own switch")
db.aspectpolish = false YaHT:ApplySettings()
assert(badge.rim.shown and not badge.polish.frame.shown, "the aspect badge's standard look")
-- an icon with its own look has its own switch
db.rapidfireown, db.rapidfireiconpolish = true, true YaHT:ApplySettings()
assert(r.polish.frame.shown and not r.border.shown, "an icon's own look should have its own polish")
db.rapidfireown, db.procpolish, db.aspectpolish = false, true, true YaHT:ApplySettings()
assert(r.polish.frame.shown and badge.polish.frame.shown, "the polished look should come back")

-- squares, while you place things (bar unlocked): two samples that run, half a turn apart, in place of the circles
db.hawkshape = "SQUARE" YaHT:ApplySettings() run(0.3)
assert(s1.shown and s2.shown and not c1.shown and not c2.shown, "the squares should take the circles' place")
assert(s1.icon.tex == "hawk-icon", "not the Summon Hawk icon: "..tostring(s1.icon.tex))
assert(s1.polish.frame.shown and not s1.border.shown, "a square hawk takes the look all proc icons share")
assert(h.shown and h.w == 2 * (db.procsize + 2) + 6 and h.h == (db.procsize + 6) + 15, "two proc icons side by side, and the row of numbers: "..tostring(h.w).." x "..tostring(h.h))
assert(s1.point[1] == "TOPLEFT" and s1.point[2] == h and s1.point[4] == 0 and s2.point[4] == db.procsize + 2 + 6, "the squares should stand in the holder, side by side")
assert(h.point[1] == "BOTTOMLEFT" and h.point[2] == bar and h.point[3] == "TOPLEFT", "still at the bar's top left")
assert(tonumber(s1.num.txt) and tonumber(s2.num.txt) and s1.num.txt ~= s2.num.txt, "the samples should show their seconds: "..tostring(s1.num.txt).." "..tostring(s2.num.txt))
assert(w.shown, "the numbers follow the running samples")

-- locked, no hawk out: nothing on screen, nothing running
db.lock = true YaHT:ApplySettings() run(0.6)
assert(not s1.shown and not s2.shown and not h.shown and not w.shown, "should be away and asleep with no hawk out")

-- you cast Summon Hawk: the first square runs for 18 seconds, like a proc icon
local t1 = GetTime()
cast() run(0.3)
assert(s1.proc and s1.shown and near(s1.procStart, t1) and s1.window == 18, "the first hawk has no running square")
assert(not s2.shown and s1.num.txt == "18" and not red(s1), "one hawk: one gold square with 18 on it: "..tostring(s1.num.txt))
assert(not c1.shown, "a circle showed in the square shape")
-- a second one six seconds later, with the sound of the shared look switched on: one sound per cast
run(5.7)
db.procsound = true
local t2, heard = GetTime(), #sounds
cast()
assert(#sounds == heard + 1, "a square hawk should make the proc icons' sound when you cast it")
run(0.2)
db.procsound = false
assert(s2.proc and s2.shown and near(s2.procStart, t2), "the second hawk didn't take the second square")
-- under 6 seconds the first turns red: frame, timer line, glow and number. The second stays gold.
run(6)
assert(red(s1) and not red(s2) and s1.num.txt == "6" and s2.num.txt == "12", "first hawk red under 6 seconds: "..s1.num.txt.." "..s2.num.txt)
assert(s1.num.tcolor[2] == 0.55 and s1.halo.color[2] < 0.5 and s2.halo.color[2] > 0.5, "the number and the glow should turn red too")
assert(math.abs(s1.timer.width / db.procsize - 5.8 / 18) < 0.02, "the timer line should run down over the hawk's 18 seconds")
-- the first runs out: the hawk that is left moves to the first place (the free spot is not shown)
run(6)
assert(not slots[1] and slots[2], "setup: only the second hawk should be left")
assert(s1.proc and near(s1.procStart, t2) and not s2.proc, "the hawk that is left should move to the first square")
-- with the free spot shown, a hawk keeps its square and the free one is greyed out
db.hawkempty = true YaHT:ApplySettings() run(0.2)
assert(s2.proc and near(s2.procStart, t2) and not s1.proc and h.ghosts[1].shown and not h.ghosts[2].shown, "the free square should show greyed out")
assert(h.ghosts[1].icon.alpha == 0.3 and h.ghosts[1].icon.desat == true, "the free square should be dim")
db.hawkempty = false YaHT:ApplySettings()
assert(not h.ghosts[1].shown, "the free square is a setting")
run(6.5)
assert(not slots[2] and not s1.proc and not s2.proc and not s1.shown and not s2.shown and not h.shown and not w.shown, "should be away and asleep once every hawk is gone")

-- one square with a count
db.hawkmode = "COUNT" YaHT:ApplySettings()
local a1 = GetTime()
cast() run(6)
cast() run(0.2)
assert(s1.shown and not s2.shown and near(s1.procStart, a1), "one square: the hawk that ends first")
assert(h.badge.shown and h.count.txt == "2" and h.badgeSq.shown and not h.badgeBack.shown and h.w == db.procsize + 2, "the count on a small square badge")
run(18.5)
assert(not h.shown and not s1.shown, "count layout should go away with the last hawk")
db.hawkmode = "EACH" YaHT:ApplySettings()

-- above, left or right of the bar the hawks stand in the row of the other icons, after the last of them
assert(db.mongoose and db.mongoosepos == "ABOVE" and db.rapidfire and db.rapidfirepos == "RIGHT", "setup: icons above and right of the bar")
db.hawkpos = "ABOVE" YaHT:ApplySettings()
local shift = YaHT.ProcSlotShift(db, "hawk")
assert(shift > 0 and h.point[1] == "BOTTOMLEFT" and h.point[3] == "TOP" and h.point[4] == shift - (db.procsize + 2) / 2, "above the bar: after the icons that stand there")
db.hawkpos = "RIGHT" YaHT:ApplySettings()
shift = YaHT.ProcSlotShift(db, "hawk")
assert(shift > 0 and h.point[1] == "LEFT" and h.point[3] == "RIGHT" and h.point[4] == 6 + shift, "right of the bar: after the icons that stand there")
db.hawkpos = "LEFT" YaHT:ApplySettings()
assert(h.point[1] == "RIGHT" and h.point[3] == "LEFT" and h.point[4] == -6 - YaHT.ProcSlotShift(db, "hawk"), "left of the bar")
-- (the circles can stand there too)
db.hawkshape, db.hawkpos = "CIRCLE", "ABOVE" YaHT:ApplySettings()
assert(h.point[3] == "TOP" and h.point[4] == YaHT.ProcSlotShift(db, "hawk") - db.hawksize / 2, "circles above the bar")
db.hawkshape, db.hawkpos = "SQUARE", "TOPLEFT" YaHT:ApplySettings()

-- their own look, instead of the shared one: its size and its polish are the hawks' alone
db.hawkown, db.hawkiconsize, db.hawkiconalpha, db.hawkiconglow, db.hawkiconpulse, db.hawkiconsound, db.hawkiconpolish = true, 40, 1, "NONE", "NONE", false, false
YaHT:ApplySettings()
assert(h.w == 2 * 42 + 6 and s1.border.shown and not s1.polish.frame.shown, "the hawks' own look: size 40, standard rim")
assert(r.polish.frame.shown and r.polish.frame.w == db.procsize + 2, "the hawks' own look changed another icon")
db.hawkown = false YaHT:ApplySettings()

-- changing the shape with a hawk out carries it over
local t3 = GetTime()
cast() run(0.3)
assert(s1.proc and s1.shown, "setup: a square hawk")
db.hawkshape = "CIRCLE" YaHT:ApplySettings() run(0.5)
assert(not s1.shown and c1.shown and c1.cd.shown and near(c1.cd.cooldown[1], t3), "the hawk should carry over to its circle")
db.hawkshape = "SQUARE" YaHT:ApplySettings() run(0.3)
assert(s1.proc and s1.shown and near(s1.procStart, t3) and not c1.shown, "and back to its square")
run(18.5)

-- "Preview all alerts": two sample squares that run for a few seconds, then away
YaHT:PreviewHawks(6) run(0.3)
assert(s1.proc and s2.proc and s1.num.txt == "14" and red(s2) and not red(s1), "the preview should show two running samples: "..tostring(s1.num.txt))
run(6.6)
assert(not s1.shown and not s2.shown and not h.shown and not w.shown, "the preview should end by itself")

-- ROUND ICONS. Every icon can be round; one switch (Home page, Alerts page) sets them all.
local roundAll = YaHT.optionsTable.args.alerts.args.roundall
assert(roundAll and roundAll.get() == false and db.procshape == "SQUARE" and db.aspectshape == "SQUARE", "icons should start out square")
db.procpolish = false YaHT:ApplySettings()
assert(not r.isRound and r.border.shown and r.timer.shown and not r.round.back.shown, "a square icon: its rim and its timer line")
roundAll.set({"alerts", "roundall"}, true)
for _, key in ipairs(YaHT.shapeKeys) do assert(db[key] == "CIRCLE", key.." wasn't made round by the one switch") end
assert(roundAll.get() == true and db.hawkshape == "CIRCLE", "the one switch should read on, and the hawks be circles")
-- a round proc icon: the picture inside a ring, no rim and no timer line
assert(r.isRound and r.round.back.shown and r.round.track.shown and not r.border.shown and not r.timer.shown and not r.polish.frame.shown, "Rapid Fire's icon should be round")
assert(r.round.track.tex:find("RingFlat", 1, true) and not r.round.gloss.shown and not r.round.line.shown, "standard look: a flat ring")
assert(math.abs(r.icon.w - (db.procsize + 2) * 0.8) < 1e-6 and r.round.back.w == db.procsize + 2, "the picture should sit inside its ring")
assert(badge.rim.tex:find("Disc", 1, true), "a round aspect badge has a round rim")
-- its ring is its timer: timed from the cast, in the icon's colour, running down by itself
local cw = YaHT.castBuffWatch
cw.scripts.OnEvent(cw, "UNIT_SPELLCAST_SUCCEEDED", "player", "g", 3045)
for k = 1, 6 do advance(dt) if cw.shown then cw.scripts.OnUpdate(cw, dt) end if r.shown then r.scripts.OnUpdate(r, dt) end end
local ring = r.round.ring
assert(r.proc and ring.shown and ring.cooldown and near(ring.cooldown[1], r.procStart) and ring.cooldown[2] == r.window, "the ring should be timed from the cast")
assert(ring.swipe and ring.swipe[1] > 0.8 and ring.swipe[2] > 0.6, "the ring should be gold")
-- its glow is round too: the soft halo is a round glow (no corners behind the icon), the bright ring a ring
assert(db.procglow == "HALO" and r.halo.shown and r.halo.tex:find("Halo", 1, true) and r.halo.w == r.halo.h, "a round icon's halo should be the round glow: "..tostring(r.halo.tex))
db.procglow = "RING" YaHT:ApplySettings()
for k = 1, 4 do advance(dt) r.scripts.OnUpdate(r, dt) end
assert(r.round.glow.shown and not r.halo.shown and not r.ring.T.shown, "bright ring on a round icon: a ring, not four straight lines")
db.procglow = "SHINE" YaHT:ApplySettings()
for k = 1, 4 do advance(dt) r.scripts.OnUpdate(r, dt) end
assert(r.halo.shown and not r.round.glow.shown and not r.shine.shown, "a glow that only exists with corners becomes the round halo")
db.procglow = "HALO" YaHT:ApplySettings()
for k = 1, 4 do advance(dt) r.scripts.OnUpdate(r, dt) end
-- the polished look of a round icon: the bevelled ring, a shadow, a soft light, fine edge lines
db.procpolish, db.aspectpolish = true, true YaHT:ApplySettings()
assert(r.round.gloss.shown and r.round.line.shown and r.round.shadow.shown and not r.round.track.tex:find("RingFlat", 1, true) and not r.polish.frame.shown, "a polished round icon")
assert(badge.rpolish.frame.shown and not badge.polish.frame.shown and not badge.rim.shown, "a polished round aspect badge")
-- one icon square again: the switch reads off; switching it off makes everything square
db.aspectshape = "SQUARE"
assert(roundAll.get() == false, "with one icon square the switch should read off")
roundAll.set({"alerts", "roundall"}, false)
assert(db.procshape == "SQUARE" and db.hawkshape == "SQUARE" and not r.isRound and not r.round.back.shown and not ring.shown and r.timer.shown and r.polish.frame.shown, "back to square, with the polished frame")
assert(badge.polish.frame.shown and not badge.rpolish.frame.shown, "the aspect badge square again")
for k = 1, 4 do advance(dt) r.scripts.OnUpdate(r, dt) end
assert(not r.halo.tex:find("Halo", 1, true) and not r.round.glow.shown and badge.halo.tex == r.halo.tex, "square icons keep their own glow")
-- an icon with its own look has its own shape
db.rapidfireown, db.rapidfireiconshape, db.rapidfireiconpolish, db.rapidfireiconsize = true, "CIRCLE", false, 30 YaHT:ApplySettings()
assert(r.isRound and r.round.back.shown, "an icon's own look should have its own shape")
db.rapidfireown = false YaHT:ApplySettings()
-- the square hawks stay square whatever the proc icons' shape is (round hawks are the circles)
db.procshape = "CIRCLE" YaHT:ApplySettings()
assert(not s1.isRound, "a square hawk turned round")
db.procshape = "SQUARE" YaHT:ApplySettings()

-- switched off: nothing, whatever happens
db.hawk = false YaHT:ApplySettings()
cast() run(0.3)
assert(not s1.shown and not h.shown, "switched off but showing")
db.hawk = true YaHT:ApplySettings()
assert((YaHT.errorCount or 0) == before, "YaHT reported a problem")
print("OK42")
