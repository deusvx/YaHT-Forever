-- The Macros page: a few hunter macros made with one click (into the macro list and onto the cursor).
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local page = YaHT.optionsTable.args.alerts.args.macrospage
assert(page and page.args.autoadd and page.args.feignadd and page.args.petbackadd, "no Macros page with its Add buttons")
local list = YaHT.MacroList()
assert(#list == 21, "twenty-one macros expected, got "..#list)
local seenName, perSet = {}, {PVE = 0, PET = 0, PVP = 0}
for _, m in ipairs(list) do
  assert(not seenName[m.name], "two macros share a name: "..m.name) seenName[m.name] = true
  assert(perSet[m.set], "a macro without a list: "..m.name) perSet[m.set] = perSet[m.set] + 1
  assert(page.args[m.id.."add"] and page.args[m.id.."title"], "no card for "..m.id)
end
assert(perSet.PVE == 10 and perSet.PET == 4 and perSet.PVP == 7, "the three lists: "..perSet.PVE.." "..perSet.PET.." "..perSet.PVP)
for _, m in ipairs(list) do
  assert(#m.name <= 16, "a macro's name may be 16 letters at most: "..m.name)
  assert(#m.body <= 255, "a macro's text may be 255 letters at most: "..m.name)
end
-- the game's macro list, stood in for
local macros, picked, fighting, full = {}, nil, false, false
function GetMacroIndexByName(name) for i, m in ipairs(macros) do if m.name == name then return i end end return 0 end
function CreateMacro(name, icon, body, perChar) if full then return nil end macros[#macros + 1] = {name = name, body = body, perChar = perChar} return #macros end
function EditMacro(i, name, icon, body) macros[i].name, macros[i].body = name, body return i end
function PickupMacro(name) picked = name end
function InCombatLockdown() return fighting end
-- Add: the macro is made with this character's macros, and is on the cursor
page.args.autoadd.func()
assert(#macros == 1 and macros[1].name == "YaHT Auto" and macros[1].perChar == true, "Add should make the macro")
assert(macros[1].body:find("/cast !", 1, true) and macros[1].body:find("#showtooltip", 1, true), "the Auto Shot macro's text is wrong: "..macros[1].body)
assert(picked == "YaHT Auto", "the new macro should be on the cursor")
-- its button says so for a few seconds, then reads "Add to my macros" again; its card has a picture
assert(page.args.autoadd.name() == "On your cursor: drop it on a bar", "the button should say the macro is on the cursor")
assert(page.args.feignadd.name() == "Add to my macros", "only the pressed button changes")
advance(5) assert(page.args.autoadd.name() == "Add to my macros", "the button should go back after a few seconds")
assert(type(page.args.autotitle.arg) == "table" and page.args.autotitle.arg.spell == 75 and page.args.petgotitle.arg.file, "each card should name its picture")
local M = YaHT.menu SlashCmdList["YAHT"]("") M.Show("alerts/macrospage")
local f = YaHTMenuFrame
-- the page: small cards, two side by side, each with its picture, name and an Add button
local grid
for _, r in ipairs(M.rows) do if r.kind == "macros" then grid = r end end
assert(grid and grid.shownTiles == 10, "the first list's ten macros should show as cards")
for _, r in ipairs(M.rows) do assert(not (r.item and r.item.path and r.item.path[#r.item.path].key == "autoabout"), "the macros' text rows should be gone from the page") end
local t1, t2, t3 = grid.tiles[1], grid.tiles[2], grid.tiles[3]
assert(t1.shown and t1.pic.tex and t1.name.txt == "Auto Shot" and t1.add.text.txt == "Add", "a card: picture, name, Add")
assert(t1.point[5] == t2.point[5] and t2.point[4] > t1.point[4] and t3.point[5] < t1.point[5], "two cards to a row")
assert(t1.newTag and t1.newTag.shown, "a new macro's card carries New")
-- the macro itself is on its card too, as you would type it
assert(t1.code.txt == t1.macro.body and t1.code.txt:find("/cast !Auto Shot", 1, true), "a card should show its macro's text")
-- ... in a box you can click into: clicking selects it all (for Ctrl+C); typing in it changes nothing
assert(t1.code.scripts.OnEditFocusGained and t1.code.scripts.OnTextChanged, "the macro's text should be a box you can select from")
local selected = 0
t1.code.HighlightText = function(self, a, b) if a == nil then selected = selected + 1 end end
t1.code.scripts.OnEditFocusGained(t1.code)
assert(selected == 1, "clicking into the text should select all of it")
t1.code.txt = "something typed" t1.code.scripts.OnTextChanged(t1.code, true)
assert(t1.code.txt == t1.macro.body, "typing in it must put the macro's text straight back")
t1.code.scripts.OnEditFocusLost(t1.code)
assert(grid.tiles[5].h == grid.tiles[6].h and grid.tiles[5].h > grid.tiles[7].h, "two cards in a row are as tall as the longer macro; a short pair is shorter")
-- nothing on a card is cut short: a few words under the name, each on its own line
for i = 1, 10 do local t = grid.tiles[i] assert(t.about.txt == t.macro.short and #t.macro.short <= 44, "a card's words should be the short ones: "..tostring(t.about.txt)) end
-- the macro itself is read on the right: the first card's to begin with, then the one pointed at, and it stays
local help = f.help
assert(help.title.txt == "Auto Shot" and help.text.txt:find("/cast !Auto Shot", 1, true), "the first macro's text should show on the right, got "..tostring(help.title.txt))
t2.scripts.OnEnter(t2)
assert(help.title.txt == t2.macro.title and help.text.txt:find("/startattack", 1, true), "pointing at a card should show its macro on the right")
M.Render()
assert(help.title.txt == t2.macro.title and help.text.txt:find("/startattack", 1, true), "it should stay there after the mouse moves on")
-- Add on a card makes the macro, and the button says so
local before = #macros
grid.tiles[3].add.scripts.OnClick(grid.tiles[3].add)
assert(#macros == before + 1 and macros[#macros].name == "YaHT Feign", "Add on a card should make its macro")
for _, r in ipairs(M.rows) do if r.kind == "macros" then grid = r end end
assert(grid.tiles[3].add.text.txt == "On cursor", "the card's button should say the macro is on the cursor")
YaHT.optionsMacroSet = "PVP" M.Render()
for _, r in ipairs(M.rows) do if r.kind == "macros" then grid = r end end
assert(grid.shownTiles == 7 and grid.tiles[1].name.txt == "Set your focus", "the PvP list shows its seven cards")
YaHT.optionsMacroSet = "PVE" M.Render()
M.Show("bar/lookpage")
-- three short lists: the PvP one shows its own cards only
assert(page.args.macroset and page.args.macroset.get() == "PVE")
assert(not page.args.autotitle.hidden() and page.args.focvipertitle.hidden() and page.args.petcaretitle.hidden())
page.args.macroset.set(nil, "PVP")
assert(page.args.autotitle.hidden() and not page.args.focvipertitle.hidden() and not page.args.fdpetadd.hidden())
assert(YaHT:AddMacro("focviper") == true and macros[#macros].body:find("@focus", 1, true), "a focus macro should cast on the focus")
assert(YaHT:AddMacro("petcare") == true and macros[#macros].body:find("mod:shift", 1, true))
page.args.macroset.set(nil, "PVE")
assert(YaHT:IsNew("key", "fdtraptitle") and YaHT:IsNew("key", "macroset"), "the new macros should carry New")
M.Show("bar/lookpage")
for _, r in ipairs(M.rows) do assert(not (r.pic and r.pic.shown and r.item and r.item.opt and r.item.opt.type == "header"), "other pages' titles have no picture") end
-- Add again: no second copy, and a changed text is put back
macros[1].body = "broken" picked = nil
page.args.autoadd.func()
assert(#macros == 4 and macros[1].body ~= "broken" and picked == "YaHT Auto", "adding again should repair it, not copy it")
-- not in a fight; and a full list says so without a problem
fighting = true assert(YaHT:AddMacro("flare") == false and #macros == 4, "no macro during a fight")
fighting = false full = true assert(YaHT:AddMacro("flare") == false and #macros == 4, "a full list should refuse")
full = false assert(YaHT:AddMacro("flare") == true and #macros == 5)
assert(YaHT:AddMacro("nothing") == false)
assert((YaHT.errorCount or 0) == 0, tostring(YaHT.lastError))
print("OK62")
