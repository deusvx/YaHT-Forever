-- YaHT's own options window (1.3). It is drawn from the same settings table as
-- the Ace3 dialog, so this checks that every page draws and that each kind of
-- control (switch, slider, dropdown, colour, button, text box) really changes
-- the setting, plus Home, search, profiles, the preview and the fallbacks.
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db = YaHT.db.profile
local M = YaHT.menu
local D = LibStub("AceConfigDialog-3.0")
local aceOpened = 0
D.Open = function() aceOpened = aceOpened + 1 end
assert(not YaHTMenuFrame, "the window should only be built when it is first opened")

SlashCmdList["YAHT"]("")
local f = YaHTMenuFrame
assert(f and f.shown and aceOpened == 0, "/yaht should open YaHT's own window")
assert(UISpecialFrames[1] == "YaHTMenuFrame", "Escape wouldn't close the window")

local function row(key)
  for _, r in ipairs(M.rows) do
    local p = r.item and r.item.path
    if p and p[#p].key == key then return r end
  end
end
local function ofKind(kind) for _, r in ipairs(M.rows) do if r.kind == kind then return r end end end
local function click(w) w.scripts.OnClick(w) end

-- Home: the quick looks as cards, the main switches, the preview button
assert(M.current == "home" and ofKind("cards") and ofKind("section"), "Home page incomplete")
-- three columns: on the right, what the page is for; point at a setting and it explains that one
assert(f.help and M.helpTitle == "Welcome" and f.help.title.txt == "Welcome" and f.help.text.txt:find("Pick a look", 1, true), "no welcome in the help column")
local hr for _, r in ipairs(M.rows) do if r.kind == "toggle" and r.tip then hr = r break end end
assert(hr, "no Home switch has an explanation")
hr.scripts.OnEnter(hr)
assert(hr.hover.shown and f.help.title.txt == hr.tipTitle and f.help.text.txt == hr.tip and hr.tip ~= nil, "pointing at a setting should explain it on the right")
hr.scripts.OnLeave(hr)
assert(not hr.hover.shown and f.help.title.txt == "Welcome", "the help column should go back to the page's own text")
hr.widget.scripts.OnEnter(hr.widget) assert(f.help.title.txt == hr.tipTitle, "pointing at the switch itself should explain it too")
hr.widget.scripts.OnLeave(hr.widget)
assert(f.help.foot.txt:find("Aviana", 1, true) and f.help.foot.txt:find("Tk Deadeye", 1, true), "the credits should be at the foot of the help column")
for _, r in ipairs(M.rows) do assert(r.kind ~= "note", "Home should not carry the credits as a row any more") end
-- rounded shapes from YaHT's own artwork; the settings sit on plates inside section boxes
assert(hr.plate and hr.plate.shaped and hr.plate.tex:find("YaHT\\media\\Round", 1, true), "rows should sit on rounded plates")
assert(hr.widget.knob.tex:find("media\\Dot", 1, true), "the switch knob should be round")
local shownBoxes = 0 for _, b in ipairs(f.boxes) do if b.shown then shownBoxes = shownBoxes + 1 end end
assert(shownBoxes == 2, "Home should have two section boxes (quick looks, main switches), got "..shownBoxes)
for _, key in ipairs({"aspect", "feign", "pet", "meleerange", "melee", "ammo", "roundall", "polishall", "preview"}) do
  assert(row(key), "Home is missing "..key)
end
-- the main switches carry a small picture: in colour while the switch is on, grey while it is off
local ar = row("aspect")
assert(ar.pic and ar.pic.shown and ar.pic.tex and ar.pic.desat == false and ar.picRim.shown and not ar.picFrame.shown, "the aspect switch should carry its picture")
db.aspect = false M.Render()
assert(row("aspect").pic.desat == true, "a switch that is off should show its picture in grey")
db.aspect = true M.Render()
-- the switch for every icon's shape shows what it does: its picture is round while it is on
local rr = row("roundall")
assert(rr.pic.shown and rr.picRim.shown and not rr.picRing.shown and rr.pic.desat == false, "round icons off: a square picture, in colour")
click(rr.widget) rr = row("roundall")
assert(db.procshape == "CIRCLE" and db.aspectshape == "CIRCLE" and db.hawkshape == "CIRCLE" and rr.picRing.shown and not rr.picRim.shown, "round icons on (from the Home page): a round picture")
click(rr.widget)
assert(db.procshape == "SQUARE" and db.hawkshape == "SQUARE" and not row("roundall").picRing.shown, "and square again")
db.hawkshape = "CIRCLE" M.Render() -- (the hawks start out as circles; the rest of this test expects that)
-- the switch for all polish shows what it does: its picture wears the polished frame while it is on
local pr = row("polishall")
assert(pr.pic.shown and pr.picRim.shown and not pr.picFrame.shown and pr.pic.desat == false and pr.pic.alpha == 1, "polish off: the picture in the flat look, still in colour")
click(pr.widget)
pr = row("polishall")
assert(db.procpolish and db.hawkpolish and pr.picFrame.shown and pr.picGloss.shown and not pr.picRim.shown, "polish on (from the Home page): the picture in the polished look")
click(pr.widget)
assert(not db.procpolish and not db.aspectpolish and not row("polishall").picFrame.shown, "and off again")
db.glow = false
local cards = ofKind("cards")
assert(cards.cards[3].name.txt == "Flashy", "third card should be Flashy")
-- a click on a card only SHOWS that look, in the live preview; nothing changes until "Use this look"
click(cards.cards[1]) cards = ofKind("cards")
assert(M.viewing == "MINIMAL" and db.mongoose == true and db.pet == true, "viewing a look must not change anything")
assert(cards.viewBar.shown and cards.cards[1].viewing and cards.cards[1].tag.shown and cards.cards[1].tag.txt == "Viewing", "the viewed look isn't marked")
assert(cards.viewText.txt:find("Minimal", 1, true), "the line under the cards should name the look: "..tostring(cards.viewText.txt))
assert(f.preview.icons[1].on == false and f.preview.box.caption.txt == "Preview of the look", "the live preview should show the viewed look (Minimal: no icons)")
click(cards.cancel) cards = ofKind("cards")
assert(M.viewing == nil and not cards.viewBar.shown and db.mongoose == true and f.preview.icons[1].on == true, "Cancel should leave everything as it was")
assert(f.preview.box.caption.txt == "Live preview", "the preview's caption should be back")
click(cards.cards[3]) cards = ofKind("cards")
assert(M.viewing == "FLASHY" and db.glow == false, "the Flashy card should only be viewed at first")
click(cards.use)
assert(M.viewing == nil and db.glow == true and db.glowlook == "SOFT", "Use this look didn't apply Flashy")
assert(db.procpolish == true and db.hawkpolish == true and db.pet == true and db.meleerange == true and db.procglow == "HALO", "Flashy is everything: every icon and warning, glow, the polished look")
-- each card shows its look live: just the bar for Minimal, small icons for Clean, and for Flashy
-- glowing icons, a soft glow, a light sweep and sparks; the one in use is marked
cards = ofKind("cards")
local c1, c2, c3 = cards.cards[1], cards.cards[2], cards.cards[3]
assert(c3.current and c3.tag.shown and not c1.current and not c2.current and not c1.tag.shown, "the look in use isn't marked")
-- each card holds a true small copy of the live preview, drawn from that look laid over your settings
assert(c1.pv and c2.pv and c3.pv and c1.pv ~= f.preview and c1.strip.scale < 1, "each card should hold its own small preview")
assert(c1.pv.icons[1].on == false and c1.pv.soft == false and not c1.pv.hawks[1].back.shown, "Minimal should show the bar only")
assert(c2.pv.icons[1].on == true and c2.pv.soft == false and c2.pv.hawks[1].back.shown, "Clean should show the bar with its icons and hawks, without a glow")
assert(c3.pv.icons[1].on == true and c3.pv.soft == true and c3.pv.icons[1].frame.shown, "Flashy should show the glow and polished icons")
-- the icons stand on a card where they stand on your bar: Mongoose Bite centred over it, as in the game...
assert(db.mongoosepos == "ABOVE" and c2.pv.icons[1].tex.point[1] == "BOTTOM" and c2.pv.icons[1].tex.point[4] == 0, "a card's icons should stand where yours do: "..tostring(db.mongoosepos))
-- ...and to its left once you put it there
db.mongoosepos = "LEFT" M.Render() cards = ofKind("cards")
assert(cards.cards[2].pv.icons[1].tex.point[1] == "RIGHT" and cards.cards[2].pv.icons[1].tex.point[3] == "LEFT", "the cards should follow where you place an icon")
db.mongoosepos = "ABOVE" M.Render() cards = ofKind("cards") c1, c2, c3 = cards.cards[1], cards.cards[2], cards.cards[3]
-- the small previews run like the big one, and a card says in one line what it is
c3.pv.t = 0 c3.pv.scripts.OnUpdate(c3.pv, 2.4)
assert(c3.pv.fill.width > 1 and not c1.pv.phase.shown and not c1.pv.freeNote.shown, "the cards' previews should run, without the big preview's labels")
assert(c1.desc.txt == "Just the bar." and c2.desc.txt == "The bar with its icons." and c3.desc.txt == "Everything, with every effect.", "a card should say in one line what it is")
c2.scripts.OnEnter(c2)
assert(f.help.title.txt == "Clean" and f.help.text.txt:find("Feign Death", 1, true), "pointing at a card should explain it in the help column: "..tostring(f.help.text.txt))
c2.scripts.OnLeave(c2)
-- Clean: the bar with its icons, the warnings off, no glow
click(c2) click(ofKind("cards").use)
assert(db.mongoose == true and db.aspect == true and db.hawk == true and db.feign == true and db.pet == false and db.meleerange == false and db.glow == false and db.procglow == "NONE" and db.procpolish == false, "Clean: the bar with its icons")
-- Minimal: just the bar
click(ofKind("cards").cards[1]) click(ofKind("cards").use) cards = ofKind("cards")
assert(cards.cards[1].current and not cards.cards[3].current and not cards.viewBar.shown, "the mark didn't move to Minimal")
assert(db.mongoose == false and db.aspect == false and db.hawk == false and db.ammo == false and db.pet == false and db.melee == false and db.glow == false, "Minimal: just the bar")
-- (back to everything for the rest of this test, in the standard look)
click(cards.cards[3]) click(ofKind("cards").use)
for _, key in ipairs(YaHT.polishKeys) do db[key] = false end
M.Render()
-- Lock bar sits in the header (on every page), not in the Home list
assert(f.lock and f.lock.shown and f.lock.label.txt == "Lock bar" and not row("lock"), "Lock bar should be in the header")
local was = db.lock
click(f.lock)
assert(db.lock == not was and f.lock.on == db.lock, "the header's Lock switch didn't switch")
click(f.lock) assert(db.lock == was, "the header's Lock switch didn't switch back")
-- a switch on the page: the button, or anywhere on its row
was = db.aspect
click(row("aspect").widget)
assert(db.aspect == not was and row("aspect").on == db.aspect, "a switch didn't switch")
local r = row("aspect") r.scripts.OnMouseUp(r)
assert(db.aspect == was, "clicking the row didn't switch it back")

-- every page draws
local ids = M.PageIds()
assert(#ids >= 18, "expected the pages of the menu, got "..#ids)
for _, id in ipairs(ids) do
  M.Show(id)
  assert(M.current == id and #M.rows > 0, "page "..id.." is empty")
end

-- The bar page shows the same preview cards instead of three plain buttons
-- a page's opening paragraph moves to the help column; the page itself starts with its settings
M.Show("bar/lookpage")
assert(M.helpTitle == "Look" and #M.helpText > 20 and M.helpText ~= "Point at a setting to see what it does.", "the Look page's intro should be in the help column")
assert(M.rows[1].kind ~= "description", "the intro should not also be on the page")
-- boxes left over from a longer page are hidden again
M.Show("advanced/announcepage") local few = 0 for _, b in ipairs(f.boxes) do if b.shown then few = few + 1 end end
M.Show("alerts/rangepage") local many = 0 for _, b in ipairs(f.boxes) do if b.shown then many = many + 1 end end
assert(many > few and few >= 1, "section boxes not counted per page: "..few.." / "..many)
M.Show("bar")
assert(ofKind("cards") and not row("presetminimal") and not row("presetclean") and not row("presetflashy"), "The bar page should show the quick looks as cards")
assert(row("presetdesc") or ofKind("description"), "the quick looks lost their explanation")

-- slider (a percent one with its own get/set), and greying out
M.Show("alerts/petpage")
r = row("petlowat")
assert(r and r.kind == "range" and r.value.txt == "35%", "pet slider should read 35%")
r.widget.scripts.OnValueChanged(r.widget, 0.5)
assert(db.petlowat == 50 and r.value.txt == "50%", "dragging the slider didn't set 50%")
r.widget.scripts.OnMouseUp(r.widget)
assert(row("petlowat").value.txt == "50%", "slider lost its value after the page was drawn again")
assert(not row("petlowat").off, "slider greyed out while its switch is on")
click(row("petlow").widget)
assert(db.petlow == false and row("petlowat").off and row("petlowat").widget.mouse == false, "slider not greyed out with its switch off")
assert(row("petlowat").up.mouse == false and row("petlowat").valueBtn.mouse == false, "a greyed-out slider's arrows and number still work")
click(row("petlow").widget)
-- the small arrows move one step; at the end of the range they stop
assert(row("petlowat").up.bars[1].tex:find("media\\Arrow", 1, true) and #row("petlowat").up.bars == 1, "the slider arrows should be the smooth arrow artwork")
db.petlowat = 35 M.Render()
r = row("petlowat") assert(r.value.txt == "35%", "setup: 35%")
click(r.up) assert(db.petlowat == 40 and row("petlowat").value.txt == "40%", "the up arrow didn't add a step")
click(row("petlowat").down) click(row("petlowat").down)
assert(db.petlowat == 30, "the down arrow didn't take a step off")
for i = 1, 10 do click(row("petlowat").down) end
assert(db.petlowat == 10, "the down arrow went past the lowest value")
-- double-click the number to type one: finer than the slider's steps, kept inside its range
r = row("petlowat") r.valueBtn.scripts.OnDoubleClick(r.valueBtn)
assert(r.edit.shown and not r.value.shown and r.edit.txt == "10", "double-click should open a box with the value")
r.edit.txt = "42" r.edit.scripts.OnEnterPressed(r.edit)
assert(db.petlowat == 42 and row("petlowat").value.txt == "42%" and not row("petlowat").edit.shown, "typed 42 wasn't taken")
r = row("petlowat") r.valueBtn.scripts.OnDoubleClick(r.valueBtn)
r.edit.txt = "500%" r.edit.scripts.OnEnterPressed(r.edit)
assert(db.petlowat == 60, "a typed value outside the range should stop at its end")
r = row("petlowat") r.valueBtn.scripts.OnDoubleClick(r.valueBtn)
r.edit.txt = "abc" r.edit.scripts.OnEnterPressed(r.edit)
assert(db.petlowat == 60 and row("petlowat").value.shown, "typing nonsense changed the value")
r = row("petlowat") r.valueBtn.scripts.OnDoubleClick(r.valueBtn) r.edit.scripts.OnEscapePressed(r.edit)
assert(db.petlowat == 60 and not r.edit.shown and r.value.shown, "Escape should leave the value alone")
db.petlowat = 35 M.Render()
-- a plain number slider
r = row("pettextsize") r.widget.scripts.OnValueChanged(r.widget, 15.4)
assert(db.pettextsize == 15 and r.value.txt == "15", "number slider should snap to its step")
r.valueBtn.scripts.OnDoubleClick(r.valueBtn) r.edit.txt = "17.6" r.edit.scripts.OnEnterPressed(r.edit)
assert(db.pettextsize == 18, "a typed size should round to a whole number")
db.pettextsize = 15 M.Render()

-- button with a yes/no question: nothing happens until you say yes
popups = {}
click(row("reset").widget)
assert(#popups == 1 and db.pettextsize == 15, "Reset should ask first")
popups[1].data()
assert(db.pettextsize == 12 and db.petlowat == 35 and row("petlowat").value.txt == "35%", "Reset this page didn't reset")

-- dropdown: opens a list, picking sets it
M.Show("alerts/aspectpage")
r = row("aspectwhen")
assert(r and r.kind == "select" and r.widget.text.txt == "In combat or while shooting", "dropdown should show the current choice")
click(r.widget)
local list = M.List()
assert(list and list.shown and #list.keys == 2, "the dropdown list didn't open")
for _, b in ipairs(list.rows) do if b.shown and b.key == "ALWAYS" then click(b) break end end
assert(db.aspectwhen == "ALWAYS" and not list.shown, "picking from the list didn't set it")
assert(row("aspectwhen").widget.text.txt == "Always", "dropdown didn't show the new choice")

-- colour: the game's colour picker, with cancel putting the old colour back
local picked
ColorPickerFrame = {SetupColorPickerAndShow = function(self, info) picked = info end,
  GetColorRGB = function() return 0.1, 0.2, 0.3 end, GetColorAlpha = function() return 1 end}
M.Show("bar/lookpage")
local old = db.timercolor.r
click(row("timercolor").widget)
assert(picked and picked.r == old, "colour picker not opened with the current colour")
picked.swatchFunc()
assert(db.timercolor.r == 0.1 and db.timercolor.b == 0.3, "picking a colour didn't set it")
picked.cancelFunc()
assert(db.timercolor.r == old, "cancel didn't bring the old colour back")

-- text box, and a setting that only shows when it applies
M.Show("advanced/announcepage")
db.announcetype = "SAY" M.Render()
assert(not row("targetchannel"), "a hidden setting was shown")
db.announcetype = "WHISPER" M.Render()
assert(row("targetchannel"), "a setting that applies stayed hidden")
r = row("announcemsg")
assert(r and r.kind == "input", "no text box for the announce message")
r.widget.txt = "hello" r.widget.scripts.OnEditFocusLost(r.widget)
assert(db.announcemsg == "hello", "the text box didn't save")

-- the single proc pages only show inside the Procs section
local function procChildren() local n = 0
  for _, b in ipairs(f.nav) do if b.shown and b.page:find("alerts/procspage/", 1, true) then n = n + 1 end end return n end
M.Show("alerts") assert(procChildren() == 0, "proc pages listed outside their section")
assert(f.lock.shown, "Lock bar should stay in view on other pages")
M.Show("alerts/procspage") assert(procChildren() == 4, "proc pages not listed inside their section")

-- a dropdown whose order is worked out by a function (the glow styles)
click(row("procglow").widget)
assert(M.List().shown and M.List().keys[1] == "NONE" and #M.List().keys == 5, "the glow dropdown didn't list its styles in order")
M.CloseList()

-- one icon can have its own look; the others keep the shared one
db.procsize = 40 YaHT:ApplySettings()
M.Show("alerts/procspage/mongoosepage")
assert(row("mongooseown") and not row("mongooseiconsize"), "own-look settings should stay hidden until switched on")
local sharedW = YaHT.quickShotsFrame.w
click(row("mongooseown").widget)
assert(db.mongooseown == true and db.mongooseiconsize == 40 and db.mongooseiconglow == db.procglow, "its own look should start as a copy of the shared one")
assert(row("mongooseiconsize") and row("mongooseiconglow") and row("mongooseiconpulse") and row("mongooseiconalpha") and row("mongooseiconsound"), "own-look settings not shown")
r = row("mongooseiconsize") r.valueBtn.scripts.OnDoubleClick(r.valueBtn) r.edit.txt = "56" r.edit.scripts.OnEnterPressed(r.edit)
assert(db.mongooseiconsize == 56 and YaHT.mongooseFrame.w == 58, "Mongoose Bite didn't take its own size")
assert(db.procsize == 40 and YaHT.quickShotsFrame.w == sharedW, "the other icons should keep the shared size")
click(row("mongooseown").widget)
assert(db.mongooseown == false and YaHT.mongooseFrame.w == 42 and not row("mongooseiconsize"), "switching it off should go back to the shared look")
click(row("mongooseown").widget)
assert(db.mongooseiconsize == 56, "switching it back on should keep its own values")
-- the Procs page's Reset also puts every icon back on the shared look
M.Show("alerts/procspage") popups = {} click(row("reset").widget) popups[1].data()
assert(db.mongooseown == false and db.mongooseownset == nil and db.procsize == 30 and YaHT.mongooseFrame.w == 32, "Reset didn't clear an icon's own look")

-- search: finds settings on any page, and they work right there
f.search.txt = "pulse" f.search.scripts.OnTextChanged(f.search)
assert(M.query == "pulse" and row("petpulse") and ofKind("section"), "search didn't find the pet pulse switch")
was = db.petpulse click(row("petpulse").widget)
assert(db.petpulse == not was, "a search result isn't a working switch")
M.Search("zzzz")
assert(#M.rows == 1 and M.rows[1].kind == "note" and M.rows[1].text.txt:find("zzzz", 1, true), "no 'nothing found' line")
M.Show("home") assert(M.query == nil and f.search.txt == "", "leaving the search didn't clear it")

-- a change made elsewhere (a reset, another addon) redraws the open page
db.pet = false LibStub("AceConfigRegistry-3.0"):NotifyChange("YaHT")
assert(row("pet").on == false, "the page didn't follow a change from outside")
db.pet = true

-- live preview: follows the bar's size (never wider than its strip) and runs
db.width = 600 M.Render()
assert(f.preview.w < 250 and f.preview.w >= 100, "preview should be scaled down to fit its box, got " .. tostring(f.preview.w))
assert(f.previewBox and f.previewBox.w == 276, "the preview should sit in its box at the top of the right column")
f.preview.scripts.OnUpdate(f.preview, 0.5)
assert(f.preview.num.txt == "2.1", "preview countdown not running: "..tostring(f.preview.num.txt))
-- ...and shows the bar the way it really looks: glow building up, then the sweep, sparks and a pulse
local pv = f.preview
-- the preview is a small stage: a dark panel, a pool of light and a soft shadow under the bar
assert(f.stageLight and f.stageLight.tex:find("media\\Stage", 1, true) and pv.shadow.tex:find("media\\Stage", 1, true), "the preview's stage is missing")
db.width = 300 db.glow = true db.glowlook = "SOFT" db.glowmode = "RAMP" db.glowstyle = "SWEEP" db.sparkmode = "STAND"
db.mongoose = true db.mongoosepos = "LEFT" db.procglow = "HALO" M.Render()
pv.t = 0 pv.scripts.OnUpdate(pv, 1.5) -- reloading
assert(pv.phase.txt == "Reloading" and pv.glow.shown and pv.glow.alpha > 0.05 and pv.glow.alpha < 0.7, "the glow should build up through the reload")
assert(not pv.shine.shown and not pv.sparks[1].shown and not pv.rim[1].shown, "stand-still effects showed while reloading")
local mg for _, ic in ipairs(pv.icons) do if ic.key == "mongoose" then mg = ic end end
assert(mg and mg.on and mg.bar.shown and mg.halo.shown and mg.bar.width < mg.size and mg.bar.width > 1, "the proc icon's timer should be running down")
pv.scripts.OnUpdate(pv, 0.8) -- standing still
assert(pv.phase.txt == "Stand still" and pv.shine.shown and pv.sparks[1].shown and pv.glow.alpha >= 0.6, "no sweep, sparks and full glow while standing still")
assert(pv.sparks[2].shown == (db.fill and true or false), "a second spark only when the bar fills from the middle")
db.glowlook = "OUTLINE" db.glowstyle = "BUILTIN" M.Render() pv.scripts.OnUpdate(pv, 0)
assert(pv.rim[1].shown and not pv.glow.shown and not pv.shine.shown, "the outline look should draw an outline, not a soft glow")
db.glowmode = "STAND" pv.t = 0 pv.scripts.OnUpdate(pv, 1.0)
assert(not pv.rim[1].shown, "a stand-still-only glow showed while reloading")
db.glow = false db.sparkmode = "OFF" db.procglow = "NONE" M.Render() pv.t = 0 pv.scripts.OnUpdate(pv, 2.4)
assert(not pv.glow.shown and not pv.rim[1].shown and not pv.shine.shown and not pv.sparks[1].shown and not mg.halo.shown, "effects that are switched off still showed")
db.glow = true db.sparkmode = "STAND" db.procglow = "HALO" db.glowlook = "SOFT" db.glowmode = "RAMP" M.Render()
-- the box has room for what stands above the bar, and shows it where the game does: Mongoose Bite centred
-- over the bar with the next icon to its right, and the hawk circles at the bar's top left
assert(f.previewBox.h >= 170, "the preview box is too low for the icons and hawk circles above the bar")
db.mongoosepos = "ABOVE" db.quickshots = true db.quickshotspos = "ABOVE"
db.hawkpolish = true -- (off to start with)
db.hawk = true db.hawkpos = "TOPLEFT" db.hawkmode = "EACH" db.hawknumbers = true db.hawknumpos = "BOTTOM" db.hawkwarn = 6 M.Render()
local qs for _, ic in ipairs(pv.icons) do if ic.key == "quickshots" then qs = ic end end
assert(mg.tex.point[1] == "BOTTOM" and mg.tex.point[3] == "TOP" and mg.tex.point[4] == 0, "Mongoose Bite should stand centred over the bar, as in the game")
assert(qs.on and qs.tex.point[4] > 0, "the next icon should stand to its right")
local hk = pv.hawks
assert(hk[1].back.shown and hk[2].back.shown and hk[1].icon.shown and hk[1].ring.shown, "no hawk circles in the preview")
assert(hk[1].back.point[1] == "BOTTOMLEFT" and hk[1].back.point[3] == "TOPLEFT" and hk[1].back.point[4] == 0 and hk[2].back.point[4] > 0, "hawk circles should stand at the bar's top left")
assert(hk[1].num.txt == "14" and hk[2].num.txt == "5" and hk[2].ring.color[2] < 0.5 and hk[1].ring.color[2] > 0.5, "sample hawks: 14 seconds in gold, 5 in red")
assert(hk[1].num.point[1] == "TOP", "the seconds should be under the circle")
assert(hk[1].line.shown and hk[1].halo.shown, "the preview should show the polished look")
db.hawkpolish = false M.Render()
assert(not hk[1].line.shown and not hk[1].halo.shown and not hk[1].gloss.shown and hk[1].ring.tex:find("RingFlat", 1, true), "the preview should follow the plain look")
db.hawkpolish = true M.Render()
db.hawknumpos = "MIDDLE" M.Render()
assert(hk[1].num.point[1] == "CENTER", "the preview should follow the number position")
db.hawkpos = "TOPRIGHT" M.Render()
assert(hk[2].back.point[1] == "BOTTOMRIGHT" and hk[2].back.point[4] == 0 and hk[1].back.point[4] < 0, "top right: the circles end at the bar's right edge")
db.hawkmode = "COUNT" M.Render()
assert(hk[1].back.shown and not hk[2].back.shown and pv.hawkCount.shown and pv.hawkCount.txt == "2" and hk[1].num.txt == "5", "one circle with a count")
db.hawknumbers = false M.Render()
assert(not hk[1].num.shown, "numbers switched off still show in the preview")
db.hawk = false M.Render()
assert(not hk[1].back.shown and not pv.hawkCount.shown and not pv.hawkBadge.shown, "hawk circles switched off still show in the preview")
-- the hawks as squares: drawn like the proc icons (polished frame or flat rim, timer line), where Position puts them
assert(mg.rim.shown and not mg.frame.shown, "the polished look is off to start with: the proc icons should show their flat rim")
-- round proc icons in the preview: a ring instead of the rim and the timer line
db.procshape = "CIRCLE" M.Render()
assert(mg.rring.shown and mg.rback.shown and not mg.rim.shown and not mg.bar.shown and not mg.frame.shown and mg.rring.tex:find("RingFlat", 1, true), "round proc icons should show in the preview")
assert(mg.halo.tex:find("Halo", 1, true), "a round icon's glow should be round in the preview too")
db.procshape = "SQUARE" M.Render()
assert(not mg.rring.shown and not mg.rback.shown and mg.rim.shown and mg.bar.shown, "and square again")
db.procpolish = true
db.hawk, db.hawkmode, db.hawkpos, db.hawknumbers, db.hawknumpos, db.hawkshape = true, "EACH", "TOPLEFT", true, "BOTTOM", "SQUARE" M.Render()
local sq1, sq2 = hk[1].sq, hk[2].sq
assert(sq1.tex.shown and sq2.tex.shown and not hk[1].back.shown and not hk[1].ring.shown and not hk[1].halo.shown, "square hawks should take the circles' place in the preview")
assert(sq1.frame.shown and not sq1.rim.shown and sq1.bar.shown, "a square hawk should show the polished frame and its timer line")
assert(sq2.frame.color[2] < 0.5 and sq1.frame.color[2] > 0.5 and hk[1].num.txt == "14" and hk[2].num.txt == "5", "square sample hawks: gold above 6 seconds, red under")
assert(sq1.tex.point[1] == "BOTTOMLEFT" and sq1.tex.point[4] == 0 and sq2.tex.point[4] > 0, "square hawks at the bar's top left")
assert(mg.frame.shown and not mg.rim.shown, "the proc icons should show the polished look in the preview")
db.procpolish = false M.Render()
assert(sq1.rim.shown and not sq1.frame.shown and mg.rim.shown and not mg.frame.shown and not mg.gloss.shown, "the standard look: the flat rim, on every square icon")
db.hawkown, db.hawkiconpolish, db.hawkiconglow, db.hawkiconsize = true, true, "HALO", 30 M.Render()
assert(sq1.frame.shown and not mg.frame.shown, "the hawks' own look should not change the other icons")
db.hawkown, db.procpolish = false, true M.Render()
assert(mg.frame.shown and not mg.rim.shown, "the polished look should come back")
db.hawkpos = "RIGHT" M.Render()
assert(sq1.tex.point[1] == "LEFT" and sq1.tex.point[3] == "RIGHT" and sq2.tex.point[4] > sq1.tex.point[4], "right of the bar: in the row, one after the other")
db.hawkpos = "ABOVE" M.Render()
assert(sq1.tex.point[1] == "BOTTOM" and sq1.tex.point[3] == "TOP" and sq1.tex.point[4] > 0, "above the bar: after the icons that stand there")
db.hawkmode = "COUNT" M.Render()
assert(sq1.tex.shown and not sq2.tex.shown and pv.hawkBadgeSq.shown and not pv.hawkBadge.shown and pv.hawkCount.txt == "2", "one square with a count")
db.hawkshape, db.hawkmode, db.hawkpos = "CIRCLE", "EACH", "TOPLEFT" M.Render()
db.procpolish, db.hawkpolish, db.hawkiconpolish = false, false, false M.Render()
assert(hk[1].back.shown and not sq1.tex.shown and not sq1.frame.shown and not sq1.bar.shown and not pv.hawkBadgeSq.shown, "back to circles")
-- what was dragged anywhere on the screen still shows: apart, in the corner of the preview box
local asp for _, ic in ipairs(pv.icons) do if ic.key == "aspect" then asp = ic end end
local wasAspect, wasAspectPos = db.aspect, db.aspectpos
db.aspect, db.aspectpos, db.hawk, db.hawkpos = true, "FREE", true, "TOPLEFT" M.Render()
assert(asp.on and asp.tex.shown and asp.tex.point[1] == "TOPRIGHT" and asp.tex.point[2] == pv.box, "an aspect badge placed by hand should show in the preview's corner")
assert(pv.freeNote.shown and pv.freeNote.txt == "Placed by hand", "and say why it stands apart")
db.hawkpos = "FREE" M.Render()
assert(hk[1].back.shown and hk[2].back.shown and hk[2].back.point[1] == "TOPRIGHT" and hk[2].back.point[2] == pv.box and hk[2].back.point[4] < asp.tex.point[4], "hawks placed by hand should show in the corner too, after the badge")
db.aspectpos, db.hawkpos = "LEFT", "TOPLEFT" M.Render()
assert(asp.tex.point[1] == "RIGHT" and hk[1].back.point[1] == "BOTTOMLEFT" and not pv.freeNote.shown, "back beside the bar: nothing in the corner")
db.aspect, db.aspectpos = wasAspect, wasAspectPos
db.hawk, db.hawkmode, db.hawkpos, db.hawknumbers, db.hawknumpos = true, "EACH", "TOPLEFT", true, "BOTTOM"
db.mongoosepos = "LEFT" db.quickshots = false M.Render()

-- profiles: make one from the window
M.Show("profile")
assert(M.helpText:find("active database profile", 1, true) and not M.helpText:find("Reset the current", 1, true), "only the opening paragraph belongs in the help column")
assert(ofKind("description"), "the Reset explanation should stay next to its button")
r = row("new")
assert(r and r.kind == "input" and row("choose") and row("reset"), "Profiles page incomplete")
r.widget.txt = "Raid" r.widget.scripts.OnEditFocusLost(r.widget)
assert(YaHT.db:GetCurrentProfile() == "Raid", "couldn't make a new profile from the window")
assert(row("choose").values["Raid"] and row("choose").values["Default"], "profile list not filled")

-- /yaht again closes it; /yaht classic and a missing table use the Ace3 dialog
SlashCmdList["YAHT"]("") assert(not f.shown, "/yaht didn't close the window")
SlashCmdList["YAHT"]("classic") assert(aceOpened == 1, "/yaht classic should open the Ace3 dialog")
local keep = YaHT.optionsTable YaHT.optionsTable = nil
SlashCmdList["YAHT"]("") assert(aceOpened == 2 and not f.shown, "no fallback when the window can't be drawn")
YaHT.optionsTable = keep
print("OK36")
