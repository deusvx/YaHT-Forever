local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local db=YaHT.db.profile local f=YaHT.mainFrame
db.lock=true YaHT:ApplySettings()
SlashCmdList.YAHT("copy") print("empty log text:", YaHT.copyFrame.editBox.txt)
SlashCmdList.YAHT("debug")
fire("START_AUTOREPEAT_SPELL")
for i=1,3 do for k=1,250 do advance(0.01) f.scripts.OnUpdate(f,0.01) end fire("PLAYER_SWING", 2.24, 2) end
SlashCmdList.YAHT("copy")
local txt=YaHT.copyFrame.editBox.txt
local n=0 for _ in txt:gmatch("[^\n]+") do n=n+1 end
print("log lines:", n, "saved in db.global:", #YaHT.db.global.debuglog)
print("first:", txt:match("^[^\n]+"))
-- typing is undone
YaHT.copyFrame.editBox.scripts.OnTextChanged(YaHT.copyFrame.editBox, true) print("read-only ok:", YaHT.copyFrame.editBox.txt == txt)
SlashCmdList.YAHT("clear") print("after clear:", #YaHT.db.global.debuglog)
print("OK11")
