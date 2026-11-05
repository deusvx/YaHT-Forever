local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
print("welcomed:", YaHT.db.global.welcomed, "version:", YaHT.version)
-- second "login" in same saved vars: no repeat
YaHT:OnInitialize()
print("OK19")
