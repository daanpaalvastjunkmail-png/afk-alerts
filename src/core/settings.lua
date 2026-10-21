local V = require("src/core/vars")
local S = {maxEntries=32,listKey="rs3_alerts.list.v2"}
S.order = {"health","adrenaline","prayer","summoning","skill","familiar","overload","antifire","aggression","buff","drop","idle","inventory","chat"}
local labels = {"Health","Adrenaline","Prayer","Summoning","Skill","Familiar","Overload","Antifire","Aggression","Buff","Loot drops","Skilling stopped","Inventory full","Chat message"}
S.skills = {
 {id="ATTACK",label="Attack"},{id="DEFENCE",label="Defence"},{id="STRENGTH",label="Strength"},
 {id="HITPOINTS",label="Constitution"},{id="RANGED",label="Ranged"},{id="PRAYER",label="Prayer"},
 {id="MAGIC",label="Magic"},{id="COOKING",label="Cooking"},{id="WOODCUTTING",label="Woodcutting"},
 {id="FLETCHING",label="Fletching"},{id="FISHING",label="Fishing"},{id="FIREMAKING",label="Firemaking"},
 {id="CRAFTING",label="Crafting"},{id="SMITHING",label="Smithing"},{id="MINING",label="Mining"},
 {id="HERBLORE",label="Herblore"},{id="AGILITY",label="Agility"},{id="THIEVING",label="Thieving"},
 {id="SLAYER",label="Slayer"},{id="FARMING",label="Farming"},{id="RUNECRAFTING",label="Runecrafting"},
 {id="HUNTER",label="Hunter"},{id="CONSTRUCTION",label="Construction"},{id="SUMMONING",label="Summoning"},
 {id="DUNGEONEERING",label="Dungeoneering"},{id="DIVINATION",label="Divination"},{id="INVENTION",label="Invention"},
 {id="ARCHAEOLOGY",label="Archaeology"},{id="NECROMANCY",label="Necromancy"},
}
table.sort(S.skills,function(a,b) return a.label<b.label end)
function S.defaults()
 local d = {bar={x=80,y=100},masterVolume=100,masterMuted=false,audioBus="MASTER",showHelp=true,entries={},entryOrder={},nextID=1,highlighter={enabled=false,kind="npc",names="",match="contains",colour="cyan",tileSize=1,maxEntities=30},presets={slot1="",slot2="",slot3="",slot4="",slot5="",slot6="",slot7="",slot8=""},alerts={}}
 for i,k in ipairs(S.order) do
  d.alerts[k]={label=labels[i],enabled=false,listed=false,mode="percent",threshold=20,direction="below",
   visuals={bar=true,popup=true,flash=false,circle=false},sound=k..".mp3",volume=75,muted=false,
   ["repeat"]=false,cooldown=10,hysteresis=5,hysteresisMode="percent",bar={x=0,y=48},position="top_center",positionVersion=1,
   skill="ATTACK",buffID="",timerMaximum=360,dropMetric="count",itemNameFilter="",lootSource="owned_ground",reference=100,duration=4}
 end
 d.alerts.idle.mode="absolute"; d.alerts.idle.direction="above"; d.alerts.idle.threshold=30
 d.alerts.idle.hysteresisMode="absolute"; d.alerts.idle.hysteresis=5; d.alerts.idle.skill="FISHING"
 d.alerts.idle.sound="skill.mp3"; d.alerts.idle.reference=60; d.alerts.idle.cooldown=30
 d.alerts.inventory.mode="absolute"; d.alerts.inventory.direction="above"; d.alerts.inventory.threshold=27
 d.alerts.inventory.hysteresisMode="absolute"; d.alerts.inventory.hysteresis=0
 d.alerts.inventory.sound="drop.mp3"; d.alerts.inventory.cooldown=30
 d.alerts.drop.mode="absolute"; d.alerts.drop.direction="above"; d.alerts.drop.threshold=0
 local chat=d.alerts.chat
 chat.mode="absolute"; chat.direction="above"; chat.threshold=0.5
 chat.hysteresisMode="absolute"; chat.hysteresis=0; chat.sound="skill.mp3"
 chat.chatText=""; chat.chatChannel="game"; chat.chatMatch="contains"; chat.chatCaseSensitive=false
 return d
end
function S.clone(value)
 if type(value)~="table" then return value end
 local result={}; for key,item in pairs(value) do result[key]=S.clone(item) end; return result
end
function S.newAlert(kind)
 local defaults=S.defaults().alerts[kind]
 if not defaults then return nil end
 local c=S.clone(defaults)
 c.type=kind; c.name=""; c.listed=nil
 return c
end
function S.title(c)
 if c.name and c.name~="" then return c.name end
 if c.type=="chat" then return "Chat: "..(c.chatText or "") end
 local label=c.label or c.type or "Alert"
 if c.type=="buff" then
  local timers=require("src/timers");local effect=timers.catalog[c.buffID]
  if effect then
   if effect.presenceOnly then return effect.label end
   label=effect.label
  end
 end
 local sign=c.direction=="below" and " < " or " > "
 local unit=c.mode=="percent" and "%" or (c.type=="idle" or c.type=="overload" or c.type=="familiar" or c.type=="buff" or c.type=="antifire" or c.type=="aggression") and "s" or ""
 return label..sign..tostring(c.threshold)..unit
end
function S.add(d,kind,configuration)
 if #d.entryOrder>=S.maxEntries then return nil,"Maximum of 32 alerts reached" end
 local c=S.newAlert(kind)
 if not c then return nil,"Unknown alert type" end
 for key,value in pairs(configuration or {}) do if c[key]~=nil then c[key]=S.clone(value) end end
 c.type=kind; c.label=S.defaults().alerts[kind].label
 local id
 repeat id="alert_"..d.nextID; d.nextID=d.nextID+1 until not d.entries[id]
 d.entries[id]=c; d.entryOrder[#d.entryOrder+1]=id
 return id,c
end
function S.remove(d,id)
 if not d.entries[id] then return false end
 d.entries[id]=nil
 for i,key in ipairs(d.entryOrder) do if key==id then table.remove(d.entryOrder,i); break end end
 return true
end
function S.migrateAlerts(d,alerts)
 d.entries={}; d.entryOrder={}; d.nextID=1
 for _,kind in ipairs(S.order) do
  local c=alerts[kind]
  if c and (c.enabled or c.listed) then S.add(d,kind,c) end
 end
end
local function read(path,default)
 local ok,value=pcall(function()
  if path=="rs3_alerts.v1.showHelp" then
   local value=PersistentDB:GetString(path)
   if value=="true" then return true elseif value=="false" then return false end
   return nil
  end
  if type(default)=="boolean" then return PersistentDB:GetBool(path) end
  if type(default)=="number" then return tonumber(PersistentDB:GetString(path)) end
  return PersistentDB:GetString(path)
 end)
 if not ok then V.report("storage.read",value);return nil,false end
 return value,true
end
local function walk(t,fn,path)
 for k,v in pairs(t) do
  local key=(path or "rs3_alerts.v1").."."..k
  if type(v)=="table" then walk(v,fn,key) else fn(t,k,v,key) end
 end
end
function S.load()
 local d=S.defaults()
 -- Older builds placed alerts at fixed left coordinates. Migrate only that layout.
 local positionVersion,readable=read("rs3_alerts.v1.alerts.health.positionVersion",0)
 local readFailed=not readable
 walk(d,function(t,k,v,path)
  local x,ok=read(path,v)
  if not ok then readFailed=true end
  if type(x)==type(v) and (type(x)~="number" or V.finite(x)) then t[k]=x end
 end)
 if d.alerts.drop.dropMetric=="value" then d.alerts.drop.dropMetric="ge" end
 if d.audioBus~="MASTER" and d.audioBus~="SFX" then d.audioBus="MASTER" end
 d.masterVolume=math.max(0,math.min(100,d.masterVolume))
 d.highlighter.tileSize=math.max(0.25,math.min(5,d.highlighter.tileSize))
 d.highlighter.maxEntities=math.floor(math.max(1,math.min(100,d.highlighter.maxEntities)))
 d.highlighter.names=d.highlighter.names:sub(1,512)
 if d.highlighter.kind~="npc" and d.highlighter.kind~="location" and d.highlighter.kind~="both" then d.highlighter.kind="npc" end
 if d.highlighter.match~="exact" and d.highlighter.match~="contains" then d.highlighter.match="contains" end
 local defaults=S.defaults()
 for key,a in pairs(d.alerts) do
  a.label=defaults.alerts[key].label
  if positionVersion~=1 then a.position="top_center"; a.positionVersion=1; a.bar={x=0,y=48} end
  a.volume=math.max(0,math.min(100,a.volume)); a.cooldown=math.max(0.1,a.cooldown)
  a.threshold=math.max(0,a.threshold); a.hysteresis=math.max(0,a.hysteresis)
  a.duration=math.max(0.1,a.duration)
 end
 local code,listReadable=read(S.listKey,"")
 if code and code~="" then
  local preset,err=require("src/core/presets").decode(code)
  if preset then require("src/core/presets").apply(d,preset)
  else d.storageReadError=true; V.status.storage="Saved alert list could not be loaded; original retained"; V.report("storage",err) end
 else
  S.migrateAlerts(d,d.alerts)
 end
 if readFailed or not listReadable then
  d.storageUnavailable=true
  V.status.storage="Storage could not be read; reopen the plugin before saving. Existing data retained."
 end
 local savedCount=0
 for _,value in pairs(d.presets)do if value~="" then savedCount=savedCount+1 end end
 V.status.storageLoaded=string.format("%d active alerts; %d saved presets",#d.entryOrder,savedCount)
 return d
end
function S.save(d)
 if d.storageUnavailable then V.status.storage="Storage could not be read; reopen the plugin before saving. Existing data retained.";return false end
 if d.storageReadError then V.status.storage="Saved list could not be read; load a preset or add an alert to replace it"; return false end
 local P=require("src/core/presets")
 local ok,code=pcall(P.export,d,"Saved alert list")
 if not ok then V.report("storage",code); V.status.storage="Alert list could not be saved"; return false end
 local valid,err=P.decode(code)
 if not valid then V.report("storage",err); V.status.storage="Invalid alert list; not saved"; return false end
 local success=true
 -- A complete ordered list is stored as one validated record; stale per-instance keys cannot reappear.
 local globals={bar=d.bar,masterVolume=d.masterVolume,masterMuted=d.masterMuted,audioBus=d.audioBus,showHelp=d.showHelp}
 walk(globals,function(_,_,v,path)
  local written,result=pcall(function()
   if path=="rs3_alerts.v1.showHelp" then return PersistentDB:SetString(path,v and "true" or "false")
   elseif type(v)=="boolean" then return PersistentDB:SetBool(path,v)
   elseif type(v)=="number" then return PersistentDB:SetString(path,string.format("%.17g",v))
   else return PersistentDB:SetString(path,v) end
  end)
  if not written or result==false then success=false end
 end)
 -- Do not commit a new running list if a preceding preference write failed.
 if not success then V.status.storage="Storage unavailable; alert list not saved"; return false end
 -- Preserve the previous validated running list before replacing it.
 local readable,previous=pcall(function()return PersistentDB:GetString(S.listKey)end)
 if readable and type(previous)=="string" and previous~="" and previous~=code and P.decode(previous) then
  local backedUp,stored=pcall(function()return PersistentDB:SetString(S.listKey..".backup",previous)end)
  if not backedUp or stored==false then V.status.storage="Backup failed; existing alert list retained";return false end
 end
 local written,result=pcall(function() return PersistentDB:SetString(S.listKey,code) end)
 if not written or result==false then success=false end
 V.status.storage=success and "Saved" or "Storage unavailable; check GetString/SetString"
 return success
end
return S
