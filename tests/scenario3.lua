local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local R = LibStub("AceConfigRegistry-3.0")
R:ValidateOptionsTable(R:GetOptionsTable("YaHT")("dialog","AceConfigDialog-3.0"), "YaHT")
print("options valid")
local db=YaHT.db.profile
local f=YaHT.mainFrame
local function tick(n,dt) for i=1,n do advance(dt) f.scripts.OnUpdate(f,dt) end end
-- unlocked demo shows numbers + text draggable
tick(5,0.1) print("demo text:", f.text.txt, "draggable:", f.textHolder.mouse, "anchor:", f.textHolder.point[1], f.textHolder.point[3])
db.lock=true YaHT:ApplySettings()
print("locked draggable:", f.textHolder.mouse)
fire("START_AUTOREPEAT_SPELL")
fire("PLAYER_SWING", 2.24, 2)    -- windup 0.4, reload 1.84
tick(1,0.0) print("right after shot (expect 2.2):", f.text.txt)
tick(10,0.1) print("1.0s later (expect 1.2):", f.text.txt)
db.textmode="MOVE" tick(1,0.0) print("stand-still mode (expect 0.8):", f.text.txt) db.textmode="SHOT"
tick(9,0.1) print("in windup (expect ~0.3-0.4):", f.text.txt, "SwingStart", f.SwingStart~=nil)
tick(3,0.1) print("windup done (0.0):", f.text.txt)
-- snap positions
for _,k in ipairs({"INSIDE_LEFT","INSIDE_CENTER","INSIDE_RIGHT","OUTSIDE_LEFT","OUTSIDE_RIGHT","ABOVE","BELOW"}) do
  db.textpos=k YaHT:ApplySettings() local p=f.textHolder.point io.write(k,"=",p[1],">",p[3],"(",p[4],",",p[5],") ")
end print()
-- drag
db.lock=false db.textpos="OUTSIDE_RIGHT" YaHT:ApplySettings()
local h=f.textHolder
cursorX,cursorY=100,100 h.scripts.OnDragStart(h) cursorX,cursorY=130,90 h.scripts.OnUpdate(h,0.01) h.scripts.OnDragStop(h)
print("after drag offsets", db.textx, db.texty, "point", h.point[4], h.point[5])
db.showtext=false YaHT:ApplySettings() tick(1,0.1) print("hidden:", h.shown)
print("OK3")
