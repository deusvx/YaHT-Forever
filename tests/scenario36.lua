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
for _, key in ipairs({"aspect", "feign", "pet", "meleerange", "melee", "ammo", "preview"}) do
  assert(row(key), "Home is missing "..key)
end
db.glow = false
local cards = ofKind("cards")
assert(cards.cards[3].name.txt == "Flashy", "third card should be Flashy")
click(cards.cards[3])
assert(db.glow == true and db.glowlook == "SOFT", "the Flashy card didn't apply its look")
-- each card shows its look live: nothing extra for Minimal, an outline and sparks for Clean,
-- a soft glow, a light sweep and sparks for Flashy; the one in use is marked
cards = ofKind("cards")
local c1, c2, c3 = cards.cards[1], cards.cards[2], cards.cards[3]
assert(c3.current and c3.tag.shown and not c1.current and not c2.current and not c1.tag.shown, "the look in use isn't marked")
cards.t = 0 cards.scripts.OnUpdate(cards, 1.0) -- reloading
assert(not c2.rim[1].shown and not c3.shine.shown and not c3.sparks[1].shown, "wind-up effects showed while reloading")
assert(c1.fill.width > 1 and c1.num.txt == "1.6", "the cards' bars aren't running")
cards.scripts.OnUpdate(cards, 1.35) -- into the wind-up
assert(not c1.rim[1].shown and not c1.glow.shown and not c1.shine.shown and not c1.sparks[1].shown, "Minimal should show the bar only")
assert(c2.rim[1].shown and c2.sparks[1].shown and c2.sparks[2].shown and not c2.glow.shown and not c2.shine.shown, "Clean should show an outline and sparks")
assert(c3.glow.shown and c3.shine.shown and c3.sparks[1].shown and not c3.rim[1].shown, "Flashy should show a glow, a sweep and sparks")
click(c1) cards = ofKind("cards")
assert(cards.cards[1].current and not cards.cards[3].current, "the mark didn't move to Minimal")
click(cards.cards[3])
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
