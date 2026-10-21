-- Version 2 stores an ordered list of independent alerts, never executable code.
local S=require("src/core/settings")
local V=require("src/core/vars")
local Legacy=require("src/core/presets_v1")
local P={maxLength=65536}
local function trim(s) return s:match("^%s*(.-)%s*$") end
local function encode(s) return (tostring(s):gsub("([^%w_.%-])",function(c) return string.format("%%%02X",c:byte()) end)) end
local function decode(s)
 if s:gsub("%%[%x][%x]",""):find("%%") then return nil end
 return (s:gsub("%%(%x%x)",function(x) return string.char(tonumber(x,16)) end))
end
local function flatten(t,base,path,rows)
 for key,value in pairs(t) do
  if key~="label" and key~="listed" and key~="type" then
   if type(value)=="table" then flatten(value,base and base[key],path.."."..key,rows)
   elseif not base or value~=base[key] then rows[#rows+1]=path.."."..key.."="..encode(value) end
  end
 end
end
function P.export(d,name,description)
 assert(type(d.entries)=="table" and type(d.entryOrder)=="table","Independent alert list required")
 local rows={}
 for i,id in ipairs(d.entryOrder) do
  local c=assert(d.entries[id],"Missing alert in list")
  local base=assert(S.newAlert(c.type),"Unknown alert type")
  rows[#rows+1]="entries."..i..".type="..encode(c.type)
  flatten(c,base,"entries."..i,rows)
 end
 flatten(d.highlighter,nil,"highlighter",rows)
 table.sort(rows)
 local code="RS3ALERTS/2;name="..encode(name or "My alert list")..";description="..encode(description or "")..";count="..#d.entryOrder..";"..table.concat(rows,";")
 assert(#code<=P.maxLength,"Preset exceeds 64 KiB")
 return code
end
local function setValue(c,path,raw)
 local parts={}; for key in path:gmatch("[^.]+") do parts[#parts+1]=key end
 if #parts>2 or table.concat(parts,".")~=path then return nil,"Invalid setting path" end
 local node=c
 for i=1,#parts-1 do node=node[parts[i]]; if type(node)~="table" then return nil,"Unknown setting" end end
 local key=parts[#parts]
 if key=="label" or key=="type" or key=="listed" or node[key]==nil or type(node[key])=="table" then return nil,"Unknown setting" end
 if key=="name" and #raw>80 then return nil,"Alert name exceeds 80 characters" end
 if key=="sound" and #raw>128 then return nil,"Sound filename exceeds 128 characters" end
 local value,err=Legacy.validate(node,key,raw)
 if value==nil then return nil,err end
 node[key]=value; return true
end
function P.decode(text)
 if type(text)~="string" or #text>P.maxLength then return nil,"Preset must be text no longer than 64 KiB" end
 text=trim(text:gsub("^\239\187\191", "")):gsub("\r", "")
 -- Old shared presets and saved slots migrate to one entry for each listed/enabled type.
 local first
 for row in text:gmatch("[^;\n]+") do
  local value=trim(row)
  if value~="" and value:sub(1,1)~="#" then first=value; break end
 end
 if first=="RS3ALERTS/1" then
  local old,err=Legacy.decode(text)
  if not old then return nil,err end
  local data=S.defaults(); S.migrateAlerts(data,old.settings.alerts)
  data.highlighter=S.clone(old.settings.highlighter)
  return {name=old.name,description=old.description,settings=P.snapshot(data)}
 end
 local header=false; local fields={}; local name,description="Imported alert list",""
 for rawRow in text:gmatch("[^;\n]+") do
  local row=trim(rawRow)
  if row~="" and row:sub(1,1)~="#" then
   if not header then
    if row~="RS3ALERTS/2" then return nil,"Expected RS3ALERTS/2 preset code or a known activity name" end
    header=true
   else
    local path,raw=row:match("^([%w_.]+)=(.*)$")
    if not path or fields[path]~=nil then return nil,"Invalid or duplicate preset field" end
    raw=decode(raw)
    if not raw then return nil,"Invalid percent escape" end
    fields[path]=raw
   end
  end
 end
 if not header then return nil,"Missing preset header" end
 if fields.name then name=fields.name end
 if fields.description then description=fields.description end
 if #name>80 or #description>512 or name:find("[%z\1-\31\127]") or description:find("[%z\1-\31\127]") then return nil,"Invalid preset name/description" end
 local count=fields.count and tonumber(fields.count)
 if not V.finite(count) or count%1~=0 or count<0 or count>S.maxEntries then return nil,"Preset count must be an integer from 0 to 32" end
 local data=S.defaults()
 for i=1,count do
  local kind=fields["entries."..i..".type"]
  if not kind or not S.newAlert(kind) then return nil,"Missing or invalid type for alert "..i end
  S.add(data,kind)
 end
 for path,raw in pairs(fields) do
  if path~="name" and path~="description" and path~="count" then
   local index,subpath=path:match("^entries%.([1-9]%d*)%.(.+)$")
   local target
   if index then
    index=tonumber(index)
    if index>count then return nil,"Alert index outside preset list" end
    if subpath~="type" then target=data.entries[data.entryOrder[index]] end
   elseif path:match("^highlighter%.") then target=data.highlighter; subpath=path:sub(13)
   else return nil,"Unknown setting: "..path end
   if target then
    local ok,err=setValue(target,subpath,raw)
    if not ok then return nil,path..": "..tostring(err) end
   end
  end
 end
 for _,id in ipairs(data.entryOrder) do
  local c=data.entries[id]
  if c.type=="chat" then
   if not c.chatText:find("%S") then return nil,"Enter a chat trigger word or phrase" end
   if c.mode~="absolute" or c.direction~="above" or c.threshold~=0.5 or c.hysteresis~=0 or c.hysteresisMode~="absolute" then
    return nil,"Chat alerts require the standard message trigger settings"
   end
  end
 end
 if name=="" then name="Imported alert list" end
 return {name=name,description=description,settings=P.snapshot(data)}
end
function P.snapshot(d)
 return {entries=S.clone(d.entries),entryOrder=S.clone(d.entryOrder),nextID=d.nextID,highlighter=S.clone(d.highlighter)}
end
function P.apply(d,preset) P.restore(d,preset.settings) end
function P.restore(d,snapshot)
 d.entries=S.clone(snapshot.entries); d.entryOrder=S.clone(snapshot.entryOrder)
 d.nextID=snapshot.nextID; d.highlighter=S.clone(snapshot.highlighter); d.storageReadError=nil
end
local function activityPreset(skill)
 local d=S.defaults()
 local _,idle=S.add(d,"idle"); idle.enabled=true; idle.skill=skill; idle["repeat"]=true
 local _,inventory=S.add(d,"inventory"); inventory.enabled=true
 return d
end
-- Guide-specific alert choices; warning thresholds are plugin defaults, not
-- PvME timings. Each style is separate so mutually exclusive setup choices
-- never get enabled together. This only builds data and never writes storage.
function P.gregorovic(style)
 assert(style=="Magic" or style=="Melee" or style=="Necromancy" or style=="Ranged","Unknown Gregorovic style")
 local d=S.defaults()
 local function add(kind,name,threshold)
  local _,c=S.add(d,kind);c.name=name;c.enabled=true;c.threshold=threshold
  c["repeat"]=true;c.cooldown=30;c.hysteresisMode="absolute";c.hysteresis=5
  return c
 end
 local function timer(identifier,name,seconds,enabled)
  local c=add("buff",name,seconds);c.buffID=identifier;c.mode="absolute";c.direction="below"
  if enabled==false then c.enabled=false end
  return c
 end
 local c=add("health","Low health - eat or heal",40)
 c.mode="percent";c.hysteresisMode="percent";c.cooldown=10;c.visuals.flash=true
 c=add("prayer","Low prayer - restore points",20);c.mode="percent";c.hysteresisMode="percent";c.cooldown=15
 c=add("overload","Elder overload salve",30);c.mode="absolute"
 timer("COMBATV2_DUEL_ARENA_REMOVAL_SCARAB_POWDER_GOLDEN_END_CLIENT","Powder of penance",60)
 timer("COMBATV2_COOLDOWN_WEAPON_POISON_END_EFFECT_CLIENT","Weapon poison",30)
 timer("COMBATV2_COOLDOWN_WILDERNESS_LUCK_POTION_ENHANCED_END_EFFECT_CLIENT","Enhanced luck potion",60)
 c=timer("COMBATV2_BUFF_NECROMANCY_DARKNESS_END_CLIENT","Darkness active - remove it for this method",0)
 c.direction="above";c.hysteresis=0
 if style=="Magic" or style=="Melee" then
  timer("COMBATV2_INCENSE_BURNER_KWUARM_END_CLIENT","Kwuarm incense sticks",60)
 end
 if style~="Necromancy" then
  timer("COMBATV2_INCENSE_BURNER_IRIT_END_CLIENT","Irit incense - if used instead of Venomblood",60)
 end
 if style=="Melee" then
  timer("COMBATV2_BUFF_VAMPYRISM_END_CLIENT","Vampyrism aspect",30)
  timer("COMBATV2_COOLDOWN_SCRIMSHAW_TIMER_END_EFFECT_CLIENT","Vampyrism scrimshaw charge",120)
  timer("COMBATV2_COOLDOWN_BONFIRE_END_EFFECT_CLIENT","Bonfire health boost (optional)",60,false)
 else
  timer("COMBATV2_COOLDOWN_GOD_BOOK_TIMER_END_EFFECT_CLIENT",style=="Necromancy" and "Scripture of Ful charge" or "Scripture of Amascut charge",120)
 end
 c=add("familiar","Familiar duration (optional)",60);c.mode="absolute";c.enabled=false
 c=add("inventory","Backpack full - collect or bank",27);c.mode="absolute";c.direction="above";c.hysteresis=0
 c=add("drop","Drop above 100k GE - collect loot",100000);c.mode="absolute";c.direction="above";c.hysteresis=0;c.dropMetric="ge";c["repeat"]=false
 return d
end
function P.builtins()
 local entries={}
 local function include(id,name,d,description)
  entries[#entries+1]={id=id,label=name,text=P.export(d,name,description)}
 end
 local function vital(d,kind,threshold)
  local _,c=S.add(d,kind); c.enabled=true; c.mode="percent"; c.direction="below"; c.threshold=threshold
 end
 local function overload(d)
  local _,c=S.add(d,"overload"); c.enabled=true; c.mode="absolute"; c.direction="below"; c.threshold=30; c.hysteresisMode="absolute"; c.hysteresis=5
 end
 local function drop(d,threshold)
  local _,c=S.add(d,"drop"); c.enabled=true; c.dropMetric="ge"; c.mode="absolute"; c.direction="above"; c.threshold=threshold; c.hysteresisMode="absolute"; c.hysteresis=0
 end
 include("afk","AFK Skilling",activityPreset("FISHING"),"Skilling stopped for 30 seconds and inventory full. Choose your skill when editing.")
 local d=S.defaults(); overload(d)
 include("overload","Overload Timer",d,"Overload below 30 seconds remaining.")
 d=S.defaults(); drop(d,0)
 include("drop","Drop Alert",d,"Owned ground drops with a Grand Exchange value above zero. Edit the value threshold to suit your goals.")
 d=S.defaults(); drop(d,100000); vital(d,"health",30); vital(d,"prayer",20); overload(d)
 include("boss","Bossing",d,"Grand Exchange drops above 100k, health below 30%, prayer below 20% and overload below 30 seconds.")
 for _,style in ipairs({"Magic","Melee","Necromancy","Ranged"})do
  include("gregorovic_"..style:lower(),"Gregorovic AFK - "..style,P.gregorovic(style),
   "PvME AFK Gregorovic: "..style..". Health/prayer, consumables, unwanted Darkness and loot. Timers arm after observation; missing or unavailable effects do not prove setup is correct. Check equipment, prayers and aura manually. https://pvme.io/pvme-guides/afk/afk-gregorovic/")
 end
 return entries
end
function P.resolve(text)
 if type(text)~="string" or #text>P.maxLength then return nil,"Preset must be text no longer than 64 KiB" end
 local query=trim(text):lower()
 if not text:find("RS3ALERTS/",1,true) then
  for _,entry in ipairs(P.builtins()) do
   if query==entry.label:lower() or query==entry.id or (entry.id=="boss" and query=="boss alerts") then return P.decode(entry.text) end
  end
  -- Keep old activity-name imports compatible without adding more included presets.
  for _,skill in ipairs(S.skills) do
   local name=skill.label:lower(); local id=skill.id:lower()
   if query==id or query==name or query=="afk "..name or query==name.." afk" or query==name.." afk reminders" then
    return P.decode(P.export(activityPreset(skill.id),"AFK Skilling","Skilling stopped and inventory full."))
   end
  end
 end
 return P.decode(text)
end
function P.preview(preset)
 local names,unknown={},{}
 local unverified={health=true,adrenaline=true,prayer=true,summoning=true,familiar=true,overload=true,antifire=true,aggression=true,buff=true}
 for _,id in ipairs(preset.settings.entryOrder) do
  local c=preset.settings.entries[id]
  names[#names+1]=S.title(c)..(c.enabled and "" or " (paused)")
  if c.enabled and unverified[c.type] then unknown[c.type]=c.label end
 end
 local warnings={}; for _,label in pairs(unknown) do warnings[#warnings+1]=label end; table.sort(warnings)
 local text=preset.name.." · "..#names.." alerts: "..table.concat(names,", ")
 if #warnings>0 then text=text.." · UNVERIFIED DATA SOURCES: "..table.concat(warnings,", ") end
 return text
end
-- Sharing envelope only; saved settings keep the existing RS3ALERTS/2 format.
-- The checksum detects damaged/missing/reordered parts, not authenticity.
local T={maxLength=P.maxLength+64,prefix="AFKPRESET/1;"}
local function checksum(text)
 local hash=2166136261
 for i=1,#text do hash=((hash ~ text:byte(i))*16777619)&0xFFFFFFFF end
 return string.format("%08x",hash)
end
function T.encode(code,err)
 if not code then return nil,err end
 local preset,why=P.decode(code)
 if not preset then return nil,why end
 local ok,payload=pcall(P.export,preset.settings,preset.name,preset.description)
 if not ok then return nil,tostring(payload) end
 return T.prefix..#payload..";"..checksum(payload)..";"..payload
end
function T.decode(text)
 if type(text)~="string" or #text>T.maxLength+1024 then return nil,"Preset transfer is too large" end
 text=text:gsub("^\239\187\191",""):match("^%s*(.-)%s*$")
 if text:sub(1,10)~="AFKPRESET/" then return text end
 -- Export pages may be joined with line breaks in a text editor.
 text=text:gsub("[\r\n]","")
 local size,hash,payload=text:match("^AFKPRESET/1;(%d+);(%x%x%x%x%x%x%x%x);(.*)$")
 size=tonumber(size)
 if not size or size>P.maxLength or not payload or #payload~=size then
  return nil,"Incomplete preset. Paste all export parts in order; use Add part for large presets."
 end
 if checksum(payload)~=hash:lower() then return nil,"Preset checksum mismatch. Clear import and copy every part again in order." end
 return payload
end
P.transfer=T
return P
