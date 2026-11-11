-- Robust start-up (1.2): if one feature fails while starting (like the
-- Feign Death alert's font did in the real game), the rest of YaHT and the
-- options menu still load, and the error is reported once in chat.
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
YaHT.InitFeign = function() error("boom") end
local printed = {}
local oldAdd = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(self, m) printed[#printed+1] = m end -- caught, not printed
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local said = false
for _,m in ipairs(printed) do if m:find("error in InitFeign") then said = true end end
assert(said, "the failing feature wasn't reported")
local R = LibStub("AceConfigRegistry-3.0")
assert(R:GetOptionsTable("YaHT"), "options menu not registered after one feature failed")
assert(YaHT.mongooseFrame and YaHT.aspectFrame, "the features that start before it didn't start")
YaHT:ApplySettings() -- must not error with the Feign Death alert missing
SlashCmdList["YAHT"]("feign") -- nor this
print("OK30")
