-- Exact bar position and the alignment grid (1.3): X and Y under The bar
-- (measured from the middle of the screen, wherever the bar was dragged), and a
-- Grid switch in the window's header / /yaht grid.
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
-- a 1920x1080 screen
UIParent.GetCenter = function() return 960, 540 end
UIParent.GetWidth = function() return 1920 end
UIParent.GetHeight = function() return 1080 end
UIParent.GetEffectiveScale = function() return 1 end
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db = YaHT.db.profile
local bar = YaHT.mainFrame
-- the fake bar reports its middle from where it was last put, or from where it was "dragged" to
local dragged
bar.GetCenter = function(s)
  if dragged then return dragged[1], dragged[2] end
  local p = s.point
  if p[1] == "CENTER" and p[3] == "CENTER" then return 960 + p[4], 540 + p[5] end
end

-- never moved: the default spot, a bit below the middle
local x, y = YaHT:GetBarOffset()
assert(x == 0 and y == -350, "default spot should read 0, -350, got "..tostring(x)..", "..tostring(y))

-- set one number: the other is kept, and the bar really moves there
YaHT:SetBarOffset(120, nil)
assert(db.point == "CENTER" and db.relativePoint == "CENTER" and db.x == 120 and db.y == -350, "setting X lost Y or the anchor")
assert(bar.point[1] == "CENTER" and bar.point[4] == 120 and bar.point[5] == -350, "the bar didn't move")
YaHT:SetBarOffset(nil, -200)
x, y = YaHT:GetBarOffset() assert(x == 120 and y == -200, "setting Y lost X")

-- dragged somewhere: the game saves a corner anchor, but X and Y still read from the middle
db.point, db.relativePoint, db.x, db.y = "TOPLEFT", "TOPLEFT", 40, -60
dragged = {300, 800}
x, y = YaHT:GetBarOffset() assert(x == -660 and y == 260, "a dragged bar's spot should be measured from the middle of the screen")
dragged = nil YaHT:SetBarOffset(nil, 0) -- nudging Y keeps the X it had
dragged = nil
assert(db.point == "CENTER" and db.y == 0, "nudging a dragged bar should re-anchor it by its middle")

-- in the options: two sliders on The bar page, with arrows and typed values
local M = YaHT.menu
YaHT:OpenMenu("bar")
local f = YaHTMenuFrame
-- the window fits the screen: full size here, drawn smaller on a small screen
assert(f.scale == 1 and f.w == 1120 and f.h == 700, "the window should be full size on a 1920x1080 screen")
YaHT:CloseMenu()
UIParent.GetWidth = function() return 1024 end UIParent.GetHeight = function() return 600 end
YaHT:OpenMenu("bar")
assert(f.scale < 0.81 and f.scale > 0.78, "the window should shrink to fit a small screen, got "..tostring(f.scale))
YaHT:CloseMenu()
UIParent.GetWidth = function() return 1920 end UIParent.GetHeight = function() return 1080 end
YaHT:OpenMenu("bar")
assert(f.scale == 1, "the window should be full size again")
local function row(key) for _, r in ipairs(M.rows) do local p = r.item and r.item.path if p and p[#p].key == key then return r end end end
YaHT:SetBarOffset(10, 20) M.Render()
local rx, ry = row("barx"), row("bary")
assert(rx and ry and rx.kind == "range" and rx.value.txt == "10" and ry.value.txt == "20", "no X / Y sliders showing the bar's spot")
rx.up.scripts.OnClick(rx.up)
assert(db.x == 11 and row("barx").value.txt == "11", "the X arrow should move the bar one step")
ry = row("bary") ry.down.scripts.OnClick(ry.down) assert(db.y == 19, "the Y arrow should move the bar one step")
rx = row("barx") rx.valueBtn.scripts.OnDoubleClick(rx.valueBtn) rx.edit.txt = "-345" rx.edit.scripts.OnEnterPressed(rx.edit)
assert(db.x == -345 and bar.point[4] == -345, "typing an exact X didn't place the bar")
-- Reset position puts it back
popups = {} row("resetpos").widget.scripts.OnClick(row("resetpos").widget)
x, y = YaHT:GetBarOffset() assert(db.point == nil and x == 0 and y == -350 and row("barx").value.txt == "0", "Reset position didn't reset X / Y")
-- dragging the bar updates the open page
dragged = {1000, 500} bar.scripts.OnDragStop(bar)
assert(row("barx").value.txt == "40" and row("bary").value.txt == "-40", "X / Y didn't follow a drag")
dragged = nil

-- the Grid switch, next to Lock bar
assert(f.grid and f.grid.shown and f.grid.label.txt == "Grid" and f.grid.on == false, "no Grid switch in the header")
assert(not YaHTGridFrame, "the grid should only be drawn when first shown")
f.grid.scripts.OnClick(f.grid)
local g = YaHTGridFrame
assert(g and g.shown and YaHT:GridShown() and f.grid.on == true, "the Grid switch didn't show the grid")
-- 1920 wide, lines every 32 from the middle: 61 across and 33 down
assert(g.lines == 61 + 33, "unexpected number of grid lines: "..tostring(g.lines))
f.grid.scripts.OnClick(f.grid) assert(not g.shown and f.grid.on == false, "the Grid switch didn't hide the grid")
SlashCmdList["YAHT"]("grid") assert(g.shown and f.grid.on == true, "/yaht grid didn't show the grid")
-- it stays up when the window closes (so you can drag things over it)
YaHT:CloseMenu() assert(g.shown, "closing the window shouldn't hide the grid")
SlashCmdList["YAHT"]("grid") assert(not g.shown, "/yaht grid didn't hide the grid")
print("OK39")
