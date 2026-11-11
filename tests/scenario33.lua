-- "Anywhere" positions (1.2): every proc icon and the aspect badge can be
-- dragged freely while unlocked; the spot is saved; locked icons never catch
-- clicks; icons left by the bar still line up without the free ones.
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db=YaHT.db.profile
local q, r, a = YaHT.quickShotsFrame, YaHT.rapidFireFrame, YaHT.aspectFrame
local main = YaHT.mainFrame

-- normal positions: no mouse at all
db.lock=true YaHT:ApplySettings()
assert(not q.mouse and not r.mouse and not a.mouse, "icons by the bar must not catch clicks")

-- Quick Shots set to Anywhere: not in the row any more
db.quickshotspos="FREE" db.rapidfirepos="RIGHT" YaHT:ApplySettings()
assert(r.point[1]=="LEFT" and r.point[4]==6, "Rapid Fire should take the first spot when Quick Shots is placed freely")
assert(q.point[2]==main and q.point[5]==60, "a free icon that wasn't placed yet should start above the bar")
assert(not q.mouse, "free icon catches clicks while locked")

-- unlocked: it can be dragged, and the spot is saved
db.lock=false YaHT:ApplySettings()
assert(q.mouse, "free icon can't be dragged while unlocked")
local moved=false q.StartMoving=function() moved=true end
q.scripts.OnDragStart(q) assert(moved, "drag didn't start")
q.GetPoint=function() return "TOPLEFT", UIParent, "TOPLEFT", 420, -310 end
q.scripts.OnDragStop(q)
assert(db.quickshotspoint=="TOPLEFT" and db.quickshotsx==420 and db.quickshotsy==-310, "dragged spot not saved")
YaHT:ApplySettings()
assert(q.point[1]=="TOPLEFT" and q.point[2]==UIParent and q.point[4]==420, "saved spot not used")

-- icons by the bar can't be dragged, even unlocked
moved=false r.StartMoving=function() moved=true end r.scripts.OnDragStart(r)
assert(not moved and not r.mouse, "an icon by the bar could be dragged")

-- the aspect badge too
db.aspectpos="FREE" YaHT:ApplySettings() assert(a.mouse, "aspect badge can't be dragged")
a.GetPoint=function() return "CENTER", UIParent, "CENTER", -100, 50 end
a.scripts.OnDragStop(a) assert(db.aspectx==-100 and db.aspecty==50, "aspect spot not saved")

-- locked again: no clicks caught
db.lock=true YaHT:ApplySettings()
assert(not q.mouse and not a.mouse, "free icons catch clicks after locking")

-- options: Anywhere offered, reset puts icons back next to the bar
local R = LibStub("AceConfigRegistry-3.0")
local opts = R:GetOptionsTable("YaHT")("dialog","AceConfigDialog-3.0")
R:ValidateOptionsTable(opts, "YaHT")
assert(opts.args.alerts.args.procspage.args.quickshotspage.args.quickshotspos.values.FREE and opts.args.alerts.args.aspectpage.args.aspectpos.values.FREE, "no Anywhere choice")
opts.args.alerts.args.procspage.args.reset.func()
assert(db.quickshotspos=="RIGHT" and db.quickshotspoint==nil, "Procs reset didn't bring Quick Shots back")
opts.args.alerts.args.aspectpage.args.reset.func()
assert(db.aspectpos=="LEFT" and db.aspectpoint==nil, "Aspect reset didn't bring the badge back")
print("OK33")
