-- Range warnings as words (1.5): "DEADZONE" / "TOO FAR", movable text with your own wording.
local ev, mev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
for _,f in ipairs(frames) do if f.events.PLAYER_ENTER_COMBAT then mev=f end end
local db=YaHT.db.profile local m=YaHT.meleeFrame
local names = {[75]="Auto Shot",[2973]="Raptor Strike",[2974]="Wing Clip"}
local oldName = C_Spell.GetSpellName
C_Spell.GetSpellName = function(id) return names[id] or oldName(id) end
local auto, wing, near = true, false, true
C_Spell.IsSpellInRange = function(n) if n=="Auto Shot" then return auto elseif n=="Wing Clip" then return wing else return true end end
function CheckInteractDistance() return near end
function UnitExists() return true end
function UnitCanAttack() return true end
function InCombatLockdown() return true end
local dt=0.01
local function run(sec) for k=1,math.floor(sec/dt+0.5) do advance(dt)
  mev.scripts.OnUpdate(mev,dt) if m.shown then m.scripts.OnUpdate(m,dt) end end end
db.lock=true db.meleerange=true YaHT:ApplySettings()
local t = YaHT.rangeTextFrame
assert(t, "no range text frame")
assert(db.rangetext == false and db.rangepics == true, "text starts off, pictures on: nothing changes for anyone until asked")

-- off: no text, whatever the position
auto,wing,near=false,false,true run(0.5)
assert(m.position=="DEAD" and not t.shown, "the text showed while switched off")
-- on: the deadzone in words, in its color
db.rangetext=true YaHT:ApplySettings()
assert(t.shown and t.text.txt=="DEADZONE" and t.text.tcolor[2]==0.82, "the deadzone text should show: "..tostring(t.text.txt))
-- too far: the other words, the other color
near=false run(0.5)
assert(m.position=="FAR" and t.shown and t.text.txt=="TOO FAR" and t.text.tcolor[2]==0.25, "the too-far text should show: "..tostring(t.text.txt))
-- back in shooting range: gone
auto=true run(0.5)
assert(not t.shown, "in shooting range there is nothing to say")
-- your own wording; empty goes back to the usual words
auto,near=false,true db.rangetextdeadmsg="BACK UP!" run(0.5)
assert(t.shown and t.text.txt=="BACK UP!", "your own wording: "..tostring(t.text.txt))
db.rangetextdeadmsg="  " YaHT:ApplySettings() assert(t.text.txt=="DEADZONE", "empty wording should give the usual words")
-- each can be switched off by itself
db.rangetextdead=false YaHT:ApplySettings() assert(not t.shown, "deadzone text switched off still shows")
near=false run(0.5) assert(t.shown and t.text.txt=="TOO FAR", "too far should still show")
db.rangetextfar=false YaHT:ApplySettings() assert(not t.shown, "too-far text switched off still shows")
db.rangetextdead, db.rangetextfar = true, true
-- text only: the pictures off, the words still there
near=true run(0.5)
assert(m.striped and m.alpha>0.9, "the stripes should be showing first")
db.rangepics=false YaHT:ApplySettings() run(1)
assert(t.shown and t.text.txt=="DEADZONE" and (not m.shown or m.alpha<0.05), "text only: the stripes should be gone and the words stay")
db.rangepics=true
-- WHERE THE WORDS SIT: under the bar to start with (clear of the stripes), over it, or anywhere
assert(db.rangetextpos == "UNDER" and t.point[1] == "TOP" and t.point[3] == "BOTTOM" and t.point[5] < -8, "the words should start out under the bar, below the warning line: "..tostring(t.point[1]).." "..tostring(t.point[5]))
db.rangetextpos = "ABOVE" YaHT:ApplySettings()
assert(t.point[1] == "BOTTOM" and t.point[3] == "TOP", "over the bar")
db.lock=false YaHT:ApplySettings()
assert(not t.dragHint.shown, "attached to the bar there is nothing to drag")
db.lock=true db.rangetextpos = "FREE" YaHT:ApplySettings()
assert(t.point[1] == "CENTER", "anywhere: in the middle until it is dragged")
-- unlocked: a sample to drag, and a drag is remembered
db.lock=false YaHT:ApplySettings()
assert(t.shown and t.dragHint.shown, "unlocked, the text should show to be dragged")
t.scripts.OnDragStop(t)
assert(db.rangetextpoint=="CENTER" and db.rangetextx==10 and db.rangetexty==20, "a drag should be remembered")
db.lock=true YaHT:ApplySettings()
-- the whole warning off: no text
db.meleerange=false YaHT:ApplySettings() run(0.3) assert(not t.shown, "range warnings off, the text still shows")
db.rangetextpos = "UNDER"
-- its settings are on the Range page
local page = YaHT.optionsTable.args.alerts.args.rangepage.args
for _, key in ipairs({"rangepics","rangetext","rangetextsize","rangetextdead","rangetextdeadmsg","rangetextdeadcolor","rangetextfar","rangetextfarmsg","rangetextfarcolor"}) do
  assert(page[key], "the Range page is missing "..key)
end
-- switching the text on switches the moving pictures off; off brings them back
db.rangetext, db.rangepics = false, true
page.rangetext.set(nil, true) assert(db.rangetext == true and db.rangepics == false, "text on should switch the stripes and arrows off")
page.rangetext.set(nil, false) assert(db.rangetext == false and db.rangepics == true, "text off should bring them back")
-- THE PAGE: each warning is one dropdown, its color, its text and a Test button
local M = YaHT.menu
local function row(key) for _, r in ipairs(M.rows) do local p = r.item and r.item.path if p and p[#p].key == key then return r end end end
local function cards() local n = 0 for _, bx in ipairs(YaHTMenuFrame.boxes) do if bx.shown then n = n + 1 end end return n end
db.meleerange, db.rangetext, db.rangepics, db.lock = true, false, true, true YaHT:ApplySettings()
SlashCmdList["YAHT"]("")
M.Show("alerts/rangepage")
assert(page.rangedeadshow.get() == "PICS" and page.rangefarshow.get() == "PICS", "stripes and arrows to start with")
assert(cards() == 5, "five cards: Range warnings, Deadzone, Too far, Distance, Fine tuning; got "..cards())
for _, key in ipairs({"meleerange", "meleerangewhen", "rangedeadshow", "rangedeadcolor", "meleedeadstyle", "rangedeadtest", "rangefarshow", "rangefarcolor", "rangefartest", "rangemore"}) do
  assert(row(key), "the Range page is missing "..key)
end
for _, key in ipairs({"rangetext", "rangepics", "rangetextdead", "rangetextfar", "rangetextsize", "rangetextdeadmsg", "rangetextfarmsg", "meleewarnspeed", "meleedeadcolor"}) do
  assert(not row(key), "this should be out of the way: "..key)
end
-- the deadzone as text only: its text row comes, its stripes rows go; too far keeps its arrows
page.rangedeadshow.set(nil, "TEXT") M.Render()
assert(db.rangedead == true and db.rangedeadpics == false and db.rangetextdead == true and db.rangetext == true, "deadzone as text")
assert(db.rangefarpics == true and db.rangetextfar == false and page.rangefarshow.get() == "PICS", "too far must not change with it")
assert(row("rangetextdeadmsg") and row("rangetextsize") and not row("meleedeadstyle") and not row("rangetextfarmsg"), "the rows should follow the choice")
auto, near = false, true run(0.5)
assert(m.position == "DEAD" and t.shown and t.text.txt == "DEADZONE" and (not m.shown or m.alpha < 0.05), "deadzone as text: words, no stripes")
near = false run(0.8)
assert(m.position == "FAR" and not t.shown and m.alpha > 0.9, "too far as arrows: arrows, no words")
-- too far with both
page.rangefarshow.set(nil, "BOTH") M.Render() run(0.3)
assert(page.rangefarshow.get() == "BOTH" and t.shown and t.text.txt == "TOO FAR" and m.alpha > 0.9 and row("rangetextfarmsg"), "too far as arrows and text")
-- the deadzone off: nothing for it, too far still warns
page.rangedeadshow.set(nil, "OFF") M.Render()
near = true run(0.5)
assert(page.rangedeadshow.get() == "OFF" and m.position == "OK" and not t.shown, "the deadzone switched off should show nothing")
near = false run(0.5) assert(t.shown and t.text.txt == "TOO FAR", "too far should still warn")
-- both as text: nothing left to fine-tune
page.rangedeadshow.set(nil, "TEXT") page.rangefarshow.set(nil, "TEXT") M.Render()
assert(cards() == 4 and not row("rangemore"), "text only: four cards (no Fine tuning), got "..cards())
-- one color per warning colors the stripes and the words alike
page.rangedeadcolor.set(nil, 0.1, 0.2, 0.3)
assert(db.meleedeadcolor.r == 0.1 and db.rangetextdeadcolor.b == 0.3 and db.meleedeadcolor.a == 1, "the deadzone color should go to both")
local r1, g1 = page.rangedeadcolor.get() assert(r1 == 0.1 and g1 == 0.2, "and read back")
-- Test shows that one warning alone, whatever the real position
auto = true run(0.5) assert(m.position == "OK" and not t.shown, "in shooting range nothing shows")
page.rangefartest.func() run(0.5)
assert(m.position == "FAR" and t.shown and t.text.txt == "TOO FAR", "Test should show the too-far warning")
run(4) assert(m.position == "OK" and not t.shown, "and it ends by itself")
page.rangedeadtest.func() run(0.5) assert(m.position == "DEAD" and t.text.txt == "DEADZONE", "Test should show the deadzone warning") run(4)
-- THE LIVE PREVIEW on the Range page shows each warning the way it is set to show
do
  local pv
  for _, fr in ipairs(frames) do if fr.warnStripes and fr.shown ~= false and fr.w then pv = fr end end
  assert(pv, "no live preview with range warnings")
  local function play(sec) for i = 1, math.floor(sec / 0.05 + 0.5) do advance(0.05) pv.scripts.OnUpdate(pv, 0.05) end end
  page.rangedeadshow.set(nil, "BOTH") page.rangefarshow.set(nil, "TEXT") M.Render()
  pv.warnT = 0 play(1)
  assert(pv.warnOn == "dead" and pv.warnStripes.shown and pv.warnText.shown and pv.warnText.txt == "DEADZONE", "the deadzone should preview with stripes and words")
  play(3)
  assert(pv.warnOn == "far" and not pv.warnStripes.shown and not pv.warnArrows[1].shown and pv.warnText.txt == "TOO FAR", "too far as text should preview as words only")
  page.rangefarshow.set(nil, "PICS") M.Render() play(0.2)
  assert(pv.warnArrows[1].shown and pv.warnArrows[4].shown and not pv.warnText.shown, "too far as arrows should preview arrows")
  page.rangefarshow.set(nil, "OFF") M.Render() pv.warnT = 4 play(0.2)
  assert(pv.warnOn == "dead", "a warning that is off is not previewed; the other one shows instead")
  -- on another page they are gone, and Multi-Shot's line shows on its own page
  M.Show("alerts/multicastpage")
  for _, fr in ipairs(frames) do if fr.warnStripes and fr.shown ~= false and fr.w then pv = fr end end
  play(0.3)
  assert(not pv.warnOn and not pv.warnStripes.shown and pv.mcOn and pv.mcFill.shown, "Multi-Shot's line should preview on its page")
  db.multicast = false play(0.2) assert(not pv.mcFill.shown, "switched off, no line in the preview") db.multicast = true
  M.Show("alerts/rangepage")
end
-- back to pictures; More options then holds the fine settings
page.rangedeadshow.set(nil, "PICS") page.rangefarshow.set(nil, "PICS") YaHT.optionsMore.range = true M.Render()
assert(db.rangetext == false and cards() == 5 and row("meleewarnspeed") and row("meleefarsize") and row("meleedeadheight") and not row("rangetextsize"), "pictures again, with their fine settings")
YaHT.optionsMore.range = nil
assert((YaHT.errorCount or 0) == 0, "YaHT reported a problem")
print("OK45")
