-- The options window's finishing touches (1.5.2): a mark on what you changed and a
-- right-click to put it back, the page you left, Ctrl + wheel on a slider, a setup
-- as a line of text to share, and what's new after an update.
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end

-- someone who already had YaHT, updating to this version
YaHTdb = {global = {welcomed = true, newsSeen = "1.0.0"}}
local chat = {}
local add = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(self, msg) chat[#chat + 1] = msg end
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db = YaHT.db.profile
local M = YaHT.menu
local function said(what) for _, l in ipairs(chat) do if l:find(what, 1, true) then return true end end end
local function row(key)
  for _, r in ipairs(M.rows) do
    local p = r.item and r.item.path
    if p and p[#p].key == key then return r end
  end
end
local function noteWith(text)
  for _, r in ipairs(M.rows) do if r.item and r.item.text and r.item.text:find(text, 1, true) then return r end end
end

-- WHAT'S NEW: said once in chat, and shown on top of Home until the window is closed once
assert(YaHT.news and YaHT.news.version == YaHT.version, "the news is for another version than the addon's: update share.lua")
assert(YaHT.newsDue and said("updated to " .. YaHT.version), "an update should be announced once")
SlashCmdList["YAHT"]("")
local f = YaHTMenuFrame
assert(f.shown and M.current == "home" and noteWith("What's new in " .. YaHT.version) and noteWith("Tracking wheel"), "Home should say what is new")
f.scripts.OnHide(f) f.shown = false
assert(YaHT.newsDue == false and YaHT.db.global.newsSeen == YaHT.version, "closing the window should settle the news")
SlashCmdList["YAHT"]("")
assert(not noteWith("What's new"), "the news shouldn't come back")
-- /yaht new brings it back on request
SlashCmdList["YAHT"]("new")
assert(f.shown and noteWith("What's new in " .. YaHT.version), "/yaht new should show the news again")
f.scripts.OnHide(f)

-- CHANGED SETTINGS: nothing is marked on a fresh profile
M.Show("bar")
assert(row("width") and not row("width").mark.shown and row("width").resetKey == nil, "an untouched setting is marked as changed")
db.width = 250 M.Render()
local r = row("width")
assert(r.mark.shown and r.resetKey == "width" and r.tip:find("Right-click", 1, true), "a changed setting should be marked, and say how to put it back")
-- a right-click puts just that one back
db.height = 9 M.Render()
r = row("width")
r.scripts.OnMouseUp(r, "RightButton")
assert(db.width == 300 and db.height == 9, "a right-click should put that one setting back, and only that one")
assert(not row("width").mark.shown and row("height").mark.shown, "the marks should follow")
-- a left click on a slider's row does nothing of the kind; a switch still switches on a left click only
M.Show("alerts")
local before = db.pet
local sw = row("pet")
sw.scripts.OnMouseUp(sw, "LeftButton")
assert(db.pet == not before and row("pet").mark.shown, "a left click should flip a switch (and mark it)")
sw = row("pet")
sw.scripts.OnMouseUp(sw, "RightButton")
assert(db.pet == before and not row("pet").mark.shown, "a right-click on a changed switch should put it back, not flip it again")
sw = row("pet")
sw.scripts.OnMouseUp(sw, "RightButton")
assert(db.pet == before, "a right-click on an unchanged switch should do nothing")
-- colours count too
M.Show("bar/lookpage")
db.timercolor.r = 0.2 M.Render()
assert(row("timercolor").mark.shown, "a changed colour isn't marked")
local c = row("timercolor") c.scripts.OnMouseUp(c, "RightButton")
assert(db.timercolor.r == 1 and db.timercolor ~= YaHT.defaults.profile.timercolor, "the colour should go back to a copy of its default")
db.height = 5

-- CTRL + WHEEL on a slider moves it a step; the wheel alone scrolls the page as everywhere
M.Show("bar")
local s = row("width").widget
local ctrl = false
function IsControlKeyDown() return ctrl end
M.scrollY = 0
s.scripts.OnMouseWheel(s, 1)
assert(db.width == 300, "the wheel alone must not change a slider")
ctrl = true
s = row("width").widget s.scripts.OnMouseWheel(s, 1)
assert(db.width > 300, "Ctrl + wheel up should move the slider up a step")
local up = db.width
s = row("width").widget s.scripts.OnMouseWheel(s, -1)
assert(db.width < up, "Ctrl + wheel down should move it down a step")
ctrl = false
db.width = 300

-- THE PAGE YOU LEFT: kept for the next time the window opens, also after a reload
M.Show("alerts/petpage")
assert(YaHT.db.global.menupage == "alerts/petpage", "the page isn't remembered")
YaHT:CloseMenu() M.current = nil -- (as after a reload: only the saved page is left)
SlashCmdList["YAHT"]("")
assert(M.current == "alerts/petpage", "the window should open where you left it, opened on "..tostring(M.current))
YaHT.db.global.menupage = "no/such/page" YaHT:CloseMenu() M.current = nil
SlashCmdList["YAHT"]("")
assert(M.current == "home", "a page that no longer exists should fall back to Home")

-- A SETUP AS TEXT: only what you changed, no screen positions
assert(YaHT:ExportSetup() == "YaHT1:", "an untouched profile should export as empty: "..YaHT:ExportSetup())
db.width, db.pet, db.textpos, db.announcemsg = 250, false, "INSIDE_CENTER", "a;b=c,d%"
db.timercolor = {r = 0.2, g = 0.4, b = 0.6}
db.point, db.x, db.y = "CENTER", 12, 34
local text = YaHT:ExportSetup()
assert(text:find("width=n250", 1, true) and text:find("pet=b0", 1, true) and text:find("timercolor=c0.2,0.4,0.6,", 1, true), "export: "..text)
assert(not text:find("point", 1, true) and not text:find("=n34", 1, true), "screen positions must not be exported")
-- back to defaults, then take it in: everything comes back, the position is left alone
YaHT.db:ResetProfile() db = YaHT.db.profile
db.point, db.x, db.y, db.height = "TOP", 1, 2, 11
local ok, n = YaHT:ImportSetup(text)
assert(ok and n == 5, "import should take all five settings, took "..tostring(n))
assert(db.width == 250 and db.pet == false and db.textpos == "INSIDE_CENTER" and db.announcemsg == "a;b=c,d%", "import lost something")
assert(math.abs(db.timercolor.r - 0.2) < 1e-6 and math.abs(db.timercolor.b - 0.6) < 1e-6, "import lost the colour")
assert(db.height == 5, "what the setup doesn't mention should be at its default")
assert(db.point == "TOP" and db.x == 1, "import must leave screen positions alone")
-- undo puts back what you had
assert(YaHT:UndoImport() and db.height == 11 and db.width == 300 and db.pet == true, "undo didn't put the old settings back")
assert(not YaHT:UndoImport(), "undo twice")
-- junk is refused or left out; nothing unknown or out of range gets in
local bad, why = YaHT:ImportSetup("hello")
assert(bad == false and type(why) == "string" and db.height == 11, "something that isn't a setup must be refused and change nothing")
ok, n = YaHT:ImportSetup("YaHT1:width=n99999;height=sfive;textpos=sNOWHERE;nosuchthing=b1;pet=n3;scale=n2;lock=b1;timercolor=c9,9,9,9")
assert(ok and db.width == 600, "a number past the slider's end should be held at its end, is "..tostring(db.width))
assert(db.height == 5 and db.textpos == "OUTSIDE_RIGHT" and db.pet == true and db.nosuchthing == nil, "a wrong kind, an unknown choice or an unknown setting got in")
assert(db.timercolor.r == 1 and db.timercolor.a == 1, "a colour should be held between 0 and 1")
YaHT:UndoImport()

-- the Profiles page has it (not Advanced), and "Undo the import" only shows when there is something to undo
M.Show("advanced")
assert(not row("exportsetup"), "sharing a setup belongs with the profiles")
M.Show("profile")
assert(row("exportsetup") and row("importsetup") and not row("importundo"), "the Profiles page should have the two boxes, and no undo yet")
local box = row("importsetup")
box.onText("YaHT1:width=n260")
assert(db.width == 260 and said("Setup taken over") and row("importundo"), "pasting a setup into the box should take it over and offer undo")
row("importundo").onClick()
assert(db.width == 300 and not row("importundo"), "the undo button should put it back and go away")

-- THE LIST ON THE LEFT: every section and page in view from the start, and every section looks alike.
-- The alerts are three sections of their own (there is no "Alerts" row above them).
local order, titles
local function list()
  order, titles = {}, {}
  for _, b in ipairs(f.nav) do if b.shown then
    if b.group then order[#order + 1] = "[" .. b.text.txt .. "]" titles[#titles + 1] = b.text.txt else order[#order + 1] = b.page end
  end end
end
local function at(id) for i, p in ipairs(order) do if p == id then return i end end end
M.Show("home") list()
assert(table.concat(order, " ") == "home changed bar bar/lookpage bar/textpage bar/effectspage bar/lonewolfpage [Warnings] alerts/rangepage alerts/feignpage alerts/petpage alerts/aspectpage alerts/ammopage [Timers and icons] alerts/procspage alerts/hawkpage alerts/multicastpage alerts/meleepage [Tools] alerts/trackerpage alerts/announcepage advanced advanced/timingpage profile",
  "the list: "..table.concat(order, " "))
assert(not at("alerts") and not at("advanced/announcepage"), "no Alerts row; Tranquilizing Shot announce is with the tools")
-- a section title of the alerts looks like "The bar" and opens its first page; it is never the lit row
local bar, warn
for _, b in ipairs(f.nav) do if b.shown then if b.page == "bar" then bar = b elseif b.group and b.text.txt == "Warnings" then warn = b end end end
assert(warn.rest == bar.rest, "the alerts' sections should look like the other sections")
warn.scripts.OnClick(warn)
assert(M.current == "alerts/rangepage", "a section title should open its first page, opened "..tostring(M.current))
local lit = 0
for _, b in ipairs(f.nav) do if b.shown and b.on then lit = lit + 1 assert(b.page == "alerts/rangepage" and not b.group, "the wrong row is lit") end end
assert(lit == 1, "exactly one row should be lit, "..lit.." are")
-- search and What I changed say where a setting lives by its section, not by "Alerts"
M.Search("low on health")
local where
for _, r in ipairs(M.rows) do if r.item and r.item.custom == "section" then where = r.item.text end end
assert(where and where:find("Warnings", 1, true) and where:find("Pet", 1, true) and not where:find("Alerts", 1, true), "search should file Pet under Warnings: "..tostring(where))
M.Show("home")
-- everything fits in the list, also with the six proc pages open
M.Show("alerts/procspage/mongoosepage") list()
local rows, low = 0, 0
for _, b in ipairs(f.nav) do if b.shown then rows = rows + 1 low = low + b.rowH end end
assert(rows == 30 and low + 16 <= 700 - 50 - 10 + 1, "the list doesn't fit: "..rows.." rows, "..low.." high")

-- WHAT I CHANGED: empty to start with, then everything that is off its default, each once
YaHT.db:ResetProfile() db = YaHT.db.profile
M.Show("changed")
assert(M.helpTitle == "What I changed" and noteWith("Nothing yet") and M.ChangedCount() == 0, "the page should say there is nothing yet")
db.width, db.pet, db.petlowat = 250, false, 20
M.Show("changed")
assert(row("width") and row("pet") and row("petlowat") and M.ChangedCount() == 3, "the changed settings should be listed, found "..M.ChangedCount())
local n = 0
for _, rr in ipairs(M.rows) do local pth = rr.item and rr.item.path if pth and pth[#pth].key == "pet" then n = n + 1 end end
assert(n == 1, "a switch that is on two pages should be listed once, is listed "..n.." times")
local label
for _, b in ipairs(f.nav) do if b.shown and b.page == "changed" then label = b.text.txt end end
assert(label and label:find("(3)", 1, true), "the list should say how many: "..tostring(label))
-- a right-click there puts one back, and it leaves the list
local w = row("width") w.scripts.OnMouseUp(w, "RightButton")
assert(db.width == 300 and not row("width") and M.ChangedCount() == 2, "putting one back should take it off the list")
db.pet, db.petlowat = true, 35

-- BACK: the page you were on before, step by step; greyed when there is nowhere to go back to
M.Show("home") M.history = {} M.Render()
assert(not f.back.can, "nothing to go back to yet")
-- closing and opening the window again is not a step on the way back
YaHT:CloseMenu() SlashCmdList["YAHT"]("")
assert(M.current == "home" and not f.back.can, "reopening the window added a step back")
M.Show("bar/lookpage") M.Show("alerts/petpage") M.Show("alerts/petpage")
assert(f.back.can and #M.history == 2, "the way back should hold the two pages before, holds "..#M.history)
f.back.scripts.OnClick(f.back) assert(M.current == "bar/lookpage", "back should go to the page before")
f.back.scripts.OnClick(f.back) assert(M.current == "home" and not f.back.can, "back again should reach the start, and then be spent")
f.back.scripts.OnClick(f.back) assert(M.current == "home", "back with nowhere to go should do nothing")
DEFAULT_CHAT_FRAME.AddMessage = add
print("OK53")
