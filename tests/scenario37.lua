-- Minimap button (1.3): left-click opens the options window, right-click a
-- quick menu (lock / unlock, preview, options, hide), drag moves it around the
-- minimap; it can be switched off in the options or with /yaht minimap.
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
-- the game's minimap: 140 wide, its middle at 500,500
Minimap = CreateFrame("Frame")
Minimap:SetSize(140, 140)
Minimap.GetCenter = function() return 500, 500 end
local cursorX, cursorY = 600, 500
function GetCursorPosition() return cursorX, cursorY end

ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db = YaHT.db.profile
local b = YaHT.minimapButton
assert(b and YaHTMinimapButton == b and b.shown, "no minimap button")
local function near(x, y) return math.abs(x - y) < 1e-6 end
-- it sits on the rim, lower left by default
local point, rel, relPoint, x, y = unpack(b.point)
assert(point == "CENTER" and rel == Minimap and near(x, math.cos(math.rad(215)) * 75) and near(y, math.sin(math.rad(215)) * 75), "button not on the minimap's rim")

-- left-click: the options window
local D = LibStub("AceConfigDialog-3.0") D.Open = function() error("the Ace3 dialog should not open") end
b.scripts.OnClick(b, "LeftButton")
assert(YaHTMenuFrame and YaHTMenuFrame.shown, "left-click didn't open the options window")
b.scripts.OnClick(b, "LeftButton")
assert(not YaHTMenuFrame.shown, "a second left-click should close it")

-- right-click: the quick menu
b.scripts.OnClick(b, "RightButton")
local q = YaHTQuickMenu
assert(q and q.shown and #q.rows == 4, "right-click didn't open the quick menu")
db.lock = true b.scripts.OnClick(b, "RightButton") b.scripts.OnClick(b, "RightButton")
assert(q.rows[1].text.txt == "Unlock bar (move things)", "quick menu should offer to unlock a locked bar")
q.rows[1].scripts.OnClick(q.rows[1])
assert(db.lock == false and not q.shown, "Unlock didn't unlock (or the menu stayed open)")
b.scripts.OnClick(b, "RightButton")
assert(q.rows[1].text.txt == "Lock bar", "quick menu should offer to lock an unlocked bar")
q.rows[1].scripts.OnClick(q.rows[1]) assert(db.lock == true, "Lock didn't lock")
-- preview all alerts
b.scripts.OnClick(b, "RightButton") q.rows[2].scripts.OnClick(q.rows[2])
assert(YaHT.petFrame.previewUntil, "Preview all alerts didn't start from the quick menu")
-- options
b.scripts.OnClick(b, "RightButton") q.rows[3].scripts.OnClick(q.rows[3])
assert(YaHTMenuFrame.shown, "Options didn't open the window")
-- a click elsewhere closes the quick menu
b.scripts.OnClick(b, "RightButton") assert(q.shown) q.catcher.scripts.OnClick(q.catcher) assert(not q.shown, "clicking away didn't close the quick menu")

-- drag: follows the mouse around the minimap, and remembers the spot
b.scripts.OnDragStart(b)
assert(b.scripts.OnUpdate, "dragging didn't start")
b.scripts.OnUpdate(b, 0.02)
assert(near(db.minimapangle, 0), "cursor to the right should be angle 0, got "..tostring(db.minimapangle))
cursorX, cursorY = 500, 700 b.scripts.OnUpdate(b, 0.02)
assert(near(db.minimapangle, 90) and near(b.point[5], 75), "cursor above should put the button on top")
b.scripts.OnDragStop(b)
assert(b.scripts.OnUpdate == nil, "the button kept working after the drag ended")

-- hide it from the quick menu; /yaht minimap brings it back
b.scripts.OnClick(b, "RightButton") q.rows[4].scripts.OnClick(q.rows[4])
assert(db.minimap == false and not b.shown, "Hide this button didn't hide it")
SlashCmdList["YAHT"]("minimap")
assert(db.minimap == true and b.shown and near(b.point[5], 75), "/yaht minimap didn't bring it back where it was")

-- its switch is in the options (The bar page and Home), and the page's Reset brings it back
local M = YaHT.menu
M.Show("home")
local function row(key) for _, r in ipairs(M.rows) do local p = r.item and r.item.path if p and p[#p].key == key then return r end end end
assert(row("minimap") and row("minimap").on == true, "no Minimap button switch on Home")
row("minimap").widget.scripts.OnClick(row("minimap").widget)
assert(db.minimap == false and not b.shown, "the switch didn't hide the button")
M.Show("bar") assert(row("minimap"), "no Minimap button switch on The bar page")
popups = {} row("reset").widget.scripts.OnClick(row("reset").widget) popups[1].data()
assert(db.minimap == true and db.minimapangle == 215 and b.shown, "Reset didn't bring the button back")
print("OK37")
