-- Debug lines can be sent to another chat tab, or kept out of chat entirely
-- (1.3). Answers to /yaht commands always show in the main chat, and the log
-- keeps every line wherever they are shown.
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
-- the debug log was left on last session: it is on again after logging in
YaHTdb = {global = {debug = true}}
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
assert(YaHT.debug == true, "the debug log should stay on across logins")
SlashCmdList["YAHT"]("debug")
assert(YaHT.debug == false and YaHT.db.global.debug == false, "switching it off should be remembered too")
local main, tab = {}, {}
DEFAULT_CHAT_FRAME.AddMessage = function(self, msg) main[#main + 1] = msg end
ChatFrame3 = {AddMessage = function(self, msg) tab[#tab + 1] = msg end}
NUM_CHAT_WINDOWS = 10
function GetChatWindowInfo(i) if i == 2 then return "Combat Log" end if i == 3 then return "YaHT" end return "" end
local g = YaHT.db.global
local function logHas(text) for _, l in ipairs(g.debuglog or {}) do if l:find(text, 1, true) then return true end end return false end

-- debug off: everything goes to the main chat, as always
YaHT:Print("hello") assert(#main == 1 and #tab == 0, "a normal line should show in the main chat")

-- debug on, default: debug lines in the main chat
YaHT.debug = true
YaHT:Print("line one") assert(#main == 2 and logHas("line one"), "debug lines should show in the main chat by default")

-- sent to another tab
g.debugwindow = 3
YaHT:Print("line two") assert(#main == 2 and #tab == 1 and logHas("line two"), "debug line didn't go to the chosen tab")
-- ... but an answer to a /yaht command still shows where you typed it
SlashCmdList["YAHT"]("ammo")
assert(#main == 3 and #tab == 1 and main[3]:find("ammo", 1, true), "a /yaht answer should show in the main chat")
assert(not YaHT.replying, "the answering flag stayed on")
-- a tab that no longer exists falls back to the main chat
g.debugwindow = 7 YaHT:Print("line three") assert(#main == 4, "a missing tab should fall back to the main chat")

-- nowhere: only the log
g.debugwindow = -1
YaHT:Print("line four") assert(#main == 4 and #tab == 1 and logHas("line four"), "\"Nowhere\" should keep the line out of chat but in the log")
-- turning the log off with the command is still confirmed in the main chat
SlashCmdList["YAHT"]("debug")
assert(YaHT.debug == false and #main == 5 and main[5]:find("debug OFF", 1, true), "switching debug off wasn't confirmed")

-- the settings: Advanced page, in both menus
local R = LibStub("AceConfigRegistry-3.0")
local opts = R:GetOptionsTable("YaHT")("dialog","AceConfigDialog-3.0")
R:ValidateOptionsTable(opts, "YaHT")
local adv = opts.args.advanced.args
assert(adv.debug and adv.debugwindow, "no debug settings on the Advanced page")
local values, order = adv.debugwindow.values(), adv.debugwindow.sorting()
assert(values[0] and values[-1] and values[2] == "Chat tab: Combat Log" and values[3] == "Chat tab: YaHT" and not values[4], "chat tabs not listed")
assert(order[1] == 0 and order[2] == 2 and order[3] == 3 and order[4] == -1, "chat tabs out of order")
adv.debug.set(nil, true) assert(YaHT.debug == true and adv.debug.get() == true, "the debug switch didn't switch")
assert(g.debug == true, "the debug switch isn't remembered")
-- the log keeps the last 800 lines
for i = 1, 900 do YaHT:Print("filler "..i) end
assert(#g.debuglog == 800 and g.debuglog[800]:find("filler 900", 1, true), "the log should keep the newest 800 lines")
adv.debugwindow.set(nil, 3) assert(g.debugwindow == 3 and adv.debugwindow.get() == 3, "the tab choice wasn't saved")
-- and in YaHT's own window
local M = YaHT.menu
YaHT:OpenMenu("advanced")
local function row(key) for _, r in ipairs(M.rows) do local p = r.item and r.item.path if p and p[#p].key == key then return r end end end
assert(row("debug") and row("debug").on == true and row("debugwindow").widget.text.txt == "Chat tab: YaHT", "debug settings not shown in the window")
row("debugwindow").widget.scripts.OnClick(row("debugwindow").widget)
local list = M.List()
assert(list.shown and #list.keys == 4 and list.keys[4] == -1, "the tab dropdown didn't list the tabs")
for _, b in ipairs(list.rows) do if b.shown and b.key == -1 then b.scripts.OnClick(b) break end end
assert(g.debugwindow == -1 and row("debugwindow").widget.text.txt == "Nowhere (only the log)", "picking \"Nowhere\" didn't take")
print("OK38")
