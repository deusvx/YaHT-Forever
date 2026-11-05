import sys, lupa
try:
    from lupa import lua51 as L
except ImportError:
    import lupa as L
lua = L.LuaRuntime(unpack_returned_tuples=True)
print("runtime:", lua.eval("_VERSION"))
A = sys.argv[1]
MOCK = r'''
_G = _G
local now = 100
function GetTime() return now end
function advance(dt) now = now + dt end
moving = false
function IsPlayerMoving() if hideStats then return SECRET end return moving end
function IsFalling() return false end
function UnitClass() return "Hunter","HUNTER" end
function UnitGUID() return "Player-1" end
function UnitName() return "Onyxia" end
local function boom() error("SECRET VALUE MISUSED") end
SECRET = setmetatable({}, {__tostring=boom,__lt=boom,__le=boom,__add=boom,__sub=boom,__mul=boom,__div=boom,__concat=boom,__unm=boom,__len=boom,__index=boom})
function issecretvalue(v) return v == SECRET end
hideStats = false
function UnitRangedDamage() if hideStats then return SECRET end return 3.0 end
function GetUnitSpeed() if hideStats then return SECRET end return moving and 7 or 0 end
strlenutf8 = function(s) return #s end
WorldFrame = {}
STANDARD_TEXT_FONT="Fonts\\FRIZQT__.TTF"
cursorX,cursorY=0,0
function GetCursorPosition() return cursorX,cursorY end
function IsInInstance() return INST end
INST=true
SPEED = "Speed"
INVSLOT_RANGED = 18
AMMO = {slotID = 2512, count = 1500, weaponSub = 2, bags = nil}
function GetInventoryItemID(u, slot) if slot == 0 then return AMMO.slotID end if AMMO.noweapon then return nil end return 12345 end
function GetInventoryItemCount(u, slot) if slot == 0 and AMMO.slotID then return AMMO.count end return 0 end
function GetInventoryItemTexture(u, slot) return "ammoicon" end
C_Item = {GetItemInfoInstant=function(id)
  if id == 12345 then return id,"Weapon","Bow","INVTYPE_RANGED","bowicon",2,AMMO.weaponSub end
  if id == 2512 then return id,"Projectile","Arrow","INVTYPE_AMMO","arrowicon",6,2 end
  if id == 3030 then return id,"Projectile","Bullet","INVTYPE_AMMO","bulleticon",6,3 end
  return id,"Misc","Junk","","x",15,0 end,
  GetItemCount=function(id) return AMMO.count end}
C_Container = {GetContainerNumSlots=function(b) return AMMO.bags and #(AMMO.bags[b] or {}) or 0 end,
  GetContainerItemInfo=function(b,s) local it = AMMO.bags[b][s] return it and {itemID=it[1], stackCount=it[2], iconFileID="bagicon"} end}
NUM_BAG_SLOTS = 4
sounds = {}
SOUNDKIT = {RAID_WARNING=8959, ALARM_CLOCK_WARNING_3=12889}
function PlaySound(k) table.insert(sounds, k) end
Enum = {PlayerSwingType = {MainHand=0, OffHand=1, Ranged=2}}
function GetLocale() return "enUS" end
function UnitFactionGroup() return "Alliance","Alliance" end
function UnitRace() return "Dwarf","Dwarf" end
function GetRealmName() return "Forever" end
function GetCurrentRegion() return 1 end
function GetCurrentRegionName() return "US" end
function UnitLevel() return 60 end
function UnitNameUnmodified() return "Huntard" end
function GetNumClasses() return 0 end
LOCALIZED_CLASS_NAMES_MALE={HUNTER="Hunter"}
function GetClassInfo() end
function GetChannelName(n) return 5 end
function GetBuildInfo() return "1.60.1","1","", 16001 end
C_Spell = {GetSpellCooldown=function(id) return {startTime=GetTime(), duration=2.5} end,GetSpellName=function(id) return ({[75]="Auto Shot",[19434]="Aimed Shot",[2643]="Multi-Shot",[19801]="Tranquilizing Shot",[5384]="Feign Death"})[id] end}
sent = {}
C_ChatInfo = {SendChatMessage=function(m,t,_,tg) table.insert(sent, t..":"..m) end}
BackdropTemplateMixin = {}
UIParent = {}
DEFAULT_CHAT_FRAME = {AddMessage=function(_,m) print("CHAT", m) end}
SlashCmdList = {}
geterrorhandler = function() return function(e) print("ERR",e) end end
securecallfunction = function(f,...) return f(...) end
function hooksecurefunc() end
local function newobj(kind)
  local o = {shown=true, scripts={}, events={}, width=0, alpha=1}
  local noop=function() end
  for _,m in ipairs({"SetFrameStrata","RegisterForDrag","SetClampedToScreen","SetAllPoints","SetHorizTile","SetVertTile","SetPoint","ClearAllPoints","SetHeight","SetScale","EnableMouse","SetMovable","SetBackdropBorderColor","SetTexture","StartMoving","StopMovingOrSizing","SetOwner","ClearLines","SetInventoryItem","SetJustifyH","SetFrameLevel","SetTexCoord","SetBlendMode","SetMovable","SetMultiLine","SetAutoFocus","SetFontObject","SetFocus","HighlightText","SetScrollChild"}) do o[m]=noop end
  o.NumLines=function() return 2 end
  o.SetSize=function(s,w,h) s.w=w s.h=h s.width=w end
  o.SetShown=function(s,v) s.shown=v and true or false end
  o.SetIgnoreParentAlpha=function(s,v) s.ignore=v end
  o.GetAlpha=function(s) return s.alpha end
  o.GetFrameLevel=function() return 1 end
  o.GetEffectiveScale=function() return 1 end
  o.SetFont=function(s,f,sz,fl) s.font={f,sz,fl} return true end
  o.SetTextColor=function(s,...) s.tcolor={...} end
  o.SetText=function(s,t) s.txt=t end
  o.EnableMouse=function(s,v) s.mouse=v end
  o.SetPoint=function(s,...) s.point={...} end
  o.CreateFontString=function(s) return newobj("FontString") end
  if kind=="GameTooltip" then YaHTScanningTooltipTextRight1={GetText=function() return nil end} YaHTScanningTooltipTextRight2={GetText=function() return "Speed 2.80" end} end
  local mt = {}
  o.SetScript=function(s,k,f) s.scripts[k]=f end
  o.GetScript=function(s,k) return s.scripts[k] end
  o.RegisterEvent=function(s,e) if e=="COMBAT_LOG_EVENT_UNFILTERED" and FORBID_CLEU then error("forbidden") end s.events[e]=true end
  o.RegisterUnitEvent=function(s,e) s.events[e]=true end
  o.UnregisterEvent=function(s,e) s.events[e]=nil end
  o.Show=function(s) s.shown=true end
  o.Hide=function(s) s.shown=false end
  o.IsShown=function(s) return s.shown end
  o.SetWidth=function(s,w) assert(type(w)=="number" and w==w, "bad width") s.width=w end
  o.GetWidth=function(s) return s.width end
  o.SetAlpha=function(s,a) s.alpha=a end
  o.CreateTexture=function(s) return newobj("Texture") end
  o.SetBackdrop=function(s,b) s.backdrop=b end
  o.SetVertexColor=function(s,r,g,b) s.color={r,g,b} end
  o.GetPoint=function() return "CENTER",UIParent,"CENTER",10,20 end
  return setmetatable(o,mt)
end
function CreateFrame(kind,name) local f=newobj(kind) if name then _G[name]=f end frames=frames or {} table.insert(frames,f) return f end
'''
lua.execute(MOCK)
if len(sys.argv)>2: lua.execute("FORBID_CLEU=true")
else: lua.execute("function CombatLogGetCurrentEventInfo() return unpack(CLEU) end")
def load(path, ns):
    src=open(A+"/"+path, encoding="utf-8").read()
    f=lua.eval("function(src,name) local f,e = loadstring(src,name) if not f then error(e) end return f end")(src, path)
    f("YaHT", ns)
ns = lua.table()
for p in ["libs/LibStub/LibStub.lua","libs/CallbackHandler-1.0/CallbackHandler-1.0.lua","libs/AceDB-3.0/AceDB-3.0.lua","libs/AceDBOptions-3.0/AceDBOptions-3.0.lua","libs/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua"]:
    load(p, lua.table())
# stub dialog
lua.execute('local D=LibStub:NewLibrary("AceConfigDialog-3.0",1) function D:AddToBlizOptions() end function D:SetDefaultSize() end function D:Open(n) print("OPEN",n) end')
toc=[l.strip().replace("\\","/") for l in open(A+"/YaHT.toc") if l.strip() and not l.startswith("#") and not l.strip().startswith("libs")]
for p in toc:
    load(p, ns)
lua.execute(open(sys.argv[0].replace("harness.py","scenario.lua")).read())
