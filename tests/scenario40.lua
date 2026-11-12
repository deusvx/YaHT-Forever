-- The record and the self-test (1.3): a small always-on diary of pet / aspect
-- warnings and anything that broke, and /yaht selftest, which checks in the game
-- that everything is there, every options page draws and every alert shows.
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local chat = {}
DEFAULT_CHAT_FRAME = {AddMessage = function(_, m) chat[#chat + 1] = m end}
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db, g = YaHT.db.profile, YaHT.db.global
local function recorded(what) for _, l in ipairs(g.record or {}) do if l:find(what, 1, true) then return true end end end
local function said(what) for _, l in ipairs(chat) do if l:find(what, 1, true) then return true end end end

-- the record: starts with the session, takes lines, keeps the newest 500
assert(recorded("[session] YaHT " .. YaHT.version .. " loaded"), "the session wasn't written to the record")
YaHT:Record("test", "hello")
assert(recorded("[test] hello"), "a line wasn't recorded")
-- anything that breaks is counted and kept, once
YaHT.ReportError("somewhere", "boom") YaHT.ReportError("somewhere", "boom")
local n = 0 for _, l in ipairs(g.record) do if l:find("[error] somewhere: boom", 1, true) then n = n + 1 end end
assert(n == 1 and YaHT.errorCount == 2 and YaHT.lastError == "somewhere: boom", "a problem should be recorded once and counted every time")
for i = 1, 600 do YaHT:Record("fill", i) end
assert(#g.record == 500 and g.record[500]:find("[fill] 600", 1, true) and not recorded("[test] hello"), "the record should keep the newest 500 lines")
-- a talkative kind of line is capped on its own, so it can't push the rare ones out
YaHT:Record("pet", "rare")
for i = 1, 100 do YaHT:Record("aspect", "warning " .. i) end
n = 0 for _, l in ipairs(g.record) do if l:find("[aspect]", 1, true) then n = n + 1 end end
assert(n == 60 and recorded("[aspect] warning 100") and not recorded("[aspect] warning 40") and recorded("[pet] rare"), "aspect lines should be capped at 60: " .. n)
for i = 1, 500 do YaHT:Record("fill", i) end
-- /yaht record shows the newest lines, /yaht record clear empties it
chat = {} SlashCmdList["YAHT"]("record")
assert(said("record: 500 lines") and said("[fill] 500") and #chat == 13, "/yaht record should print the newest lines")
SlashCmdList["YAHT"]("record clear") assert(#g.record == 0, "/yaht record clear didn't empty it")

-- the self-test: not in a fight
local fighting = true
function InCombatLockdown() return fighting end
chat = {} SlashCmdList["YAHT"]("selftest")
assert(g.selftest == nil and said("out of combat"), "the self-test should wait for the fight to end")
fighting = false
-- give the fake game the things the test looks for, bar one
function UnitThreatSituation() return nil end
function IsPetAttackActive() return false end
C_Spell.IsSpellUsable = C_Spell.IsSpellUsable or function() return false end
local t = YaHT.selfTestFrame
chat = {} SlashCmdList["YAHT"]("selftest")
assert(t.shown and t.busy and g.selftest == nil, "the report should wait for the alerts to come up")
SlashCmdList["YAHT"]("selftest") -- asking again while it runs changes nothing
t.scripts.OnUpdate(t, 0.3) assert(t.shown, "the self-test finished too early")
t.scripts.OnUpdate(t, 0.4)
local r = g.selftest
assert(r and not t.shown and not t.busy and r.version == YaHT.version, "no self-test report")
local function line(what) for _, l in ipairs(r.lines) do if l:find(what, 1, true) then return l end end end
assert(r.passed > 30 and #r.lines > 50, "the report is too short: " .. r.passed .. " / " .. #r.lines)
assert(line("PASS  game: UnitThreatSituation") == "PASS  game: UnitThreatSituation" and line("PASS  game: IsPetAttackActive"), "game functions that are there should pass, with nothing after the name")
assert(line("PASS  started: pet alerts") == "PASS  started: pet alerts" and line("PASS  alerts ran clean") == "PASS  alerts ran clean", "a pass needs no explanation")
assert(line("FAIL  game: C_CurveUtil.CreateCurve: missing, needed for pet low"), "a missing game function should fail and say what it is for")
assert(line("PASS  started: the Auto Shot bar") and line("PASS  started: pet alerts") and line("PASS  started: settings"), "YaHT's parts should be listed as started")
assert(line("PASS  settings"), "the settings check is missing")
assert(line("PASS  options window: opens"), "the window should open in the test")
for _, id in ipairs(YaHT.menu.PageIds()) do assert(line("PASS  page " .. id .. ":"), "page not tested: " .. id) end
assert(line("PASS  page alerts/aspectpage"):find("dropdown with 2 choices", 1, true), "the page's first dropdown should be opened too")
assert(line("PASS  search"), "search wasn't tested")
assert(line("picture Round") and line("INFO  version: " .. YaHT.version) and line("INFO  aspect seen"), "pictures / readings missing")
assert(line("PASS  preview all alerts") and line("PASS  alert Mongoose Bite: shows") and line("PASS  alert Feign Death: shows") and line("PASS  alerts ran clean"), "alerts weren't checked")
assert(not YaHTMenuFrame.shown and not YaHT.menu.List().shown, "the test should leave the window as it found it (closed)")
assert(said("passed") and said("/reload") and recorded("[selftest]"), "no summary in chat / in the record")
assert(said("FAIL  game: C_CurveUtil.CreateCurve"), "failures should be listed in chat")
-- an alert that is switched off isn't a failure
db.feign = false chat = {} SlashCmdList["YAHT"]("selftest") t.scripts.OnUpdate(t, 0.7)
r = g.selftest assert(line("INFO  alert Feign Death: switched off"), "a switched-off alert should just be noted")
db.feign = true
-- a page that breaks is caught, named, and the test still finishes; the window stays open if it was
local opt = YaHT.optionsTable.args.alerts.args.petpage.args.petlowat
local keep = opt.get
opt.get = function() error("broken on purpose") end
YaHT:OpenMenu("bar")
chat = {} SlashCmdList["YAHT"]("selftest") t.scripts.OnUpdate(t, 0.7)
r = g.selftest
local bad = line("FAIL  page alerts/petpage")
assert(bad and bad:find("broken on purpose", 1, true), "a broken page wasn't caught: " .. tostring(bad))
assert(line("PASS  page alerts/aspectpage") and r.failed >= 2, "the other pages should still be tested")
assert(YaHTMenuFrame.shown and YaHT.menu.current == "bar", "the test should put the window back on the page it was on")
opt.get = keep
-- if the self-test's file didn't load (it was added by an update and the game wasn't restarted), say so
local keepTest = YaHT.SelfTest YaHT.SelfTest = nil
chat = {} SlashCmdList["YAHT"]("selftest") SlashCmdList["YAHT"]("record")
assert(#chat == 2 and said("quit the game completely"), "a part that isn't loaded should say how to load it")
YaHT.SelfTest = keepTest
print("OK40")
