-- Editable preset drafts are independent of the running alert list.
local S=require("src/core/settings")
local P=require("src/core/presets")
local L={}
local function writeSlot(d,slot,code)
 if d.storageUnavailable then return false end
 local previous=d.presets["slot"..slot]
 if type(previous)=="string" and previous~="" and previous~=code then
  local backedUp,saved=pcall(function()return PersistentDB:SetString("rs3_alerts.v1.presets.slot"..slot..".backup",previous)end)
  if not backedUp or saved~=true then return false end
 end
 local ok,saved=pcall(function()return PersistentDB:SetString("rs3_alerts.v1.presets.slot"..slot,code)end)
 if not ok or saved~=true then return false end
 d.presets["slot"..slot]=code
 return true
end
function L.open(code,slot)
 local preset,err=P.decode(code)
 if not preset then return nil,err end
 local data=S.defaults();P.apply(data,preset)
 return {data=data,name=preset.name,description=preset.description,slot=slot,originalCode=P.export(data,preset.name,preset.description)}
end
function L.export(session,name)
 name=name or session.name
 if type(name)~="string" or not name:find("%S") then return nil,"Enter a preset name." end
 name=name:match("^%s*(.-)%s*$")
 local ok,code=pcall(P.export,session.data,name,session.description)
 if not ok then return nil,tostring(code) end
 local valid,err=P.decode(code)
 if not valid then return nil,err end
 return code
end
function L.save(d,session,name)
 local code,err=L.export(session,name)
 if not code then return nil,err end
 local slot=session.slot
 local target=assert(P.decode(code)).name:lower()
 local selected=slot and P.decode(d.presets["slot"..slot])
 for i=1,8 do
  local saved=d.presets["slot"..i]
  local existing=saved~="" and P.decode(saved)
  if existing and existing.name:match("^%s*(.-)%s*$"):lower()==target then
   if not slot then slot=i;break end
   if i~=slot and (not selected or selected.name:match("^%s*(.-)%s*$"):lower()~=target) then
    return nil,"That name belongs to another saved preset. Select that preset to update it."
   end
  end
 end
 if not slot then for i=1,8 do if d.presets["slot"..i]=="" then slot=i;break end end end
 if not slot then return nil,"All eight saved preset slots are full. Edit an existing saved preset to replace it." end
 if not writeSlot(d,slot,code) then
  return nil,"Storage failed. Your draft is retained; try Save again."
 end
 session.slot=slot;session.name=assert(P.decode(code)).name;session.originalCode=code
 return slot
end
function L.hasChanges(session,name)
 local code=L.export(session,name)
 return code==nil or code~=session.originalCode
end
function L.list(d,query,includeStandard)
 query=(query or ""):lower():match("^%s*(.-)%s*$")
 local items={}
 for slot=1,8 do
  local code=d.presets["slot"..slot]
  if code~="" then
   local preset=P.decode(code)
   local name=preset and preset.name or ("Unreadable preset "..slot)
   if name:lower():find(query,1,true) then
    items[#items+1]={id=slot,key="saved:"..slot,slot=slot,name=name,label=name,code=code,preset=preset}
   end
  end
 end
 table.sort(items,function(a,b)if a.name:lower()==b.name:lower() then return a.slot<b.slot end;return a.name:lower()<b.name:lower()end)
 if includeStandard~=false then
 for i,builtin in ipairs(P.builtins())do
  if builtin.label:lower():find(query,1,true) then
   items[#items+1]={id=100+i,key="standard:"..builtin.id,standard=true,name=builtin.label,label=builtin.label,code=builtin.text,preset=P.decode(builtin.text)}
  end
 end
 end
 return items
end
function L.delete(d,slot,expected)
 if type(slot)~="number" or slot%1~=0 or slot<1 or slot>8 then return nil,"Only saved presets can be deleted." end
 local code=d.presets["slot"..slot]
 if code=="" then return nil,"This preset has already been deleted." end
 if code~=expected then return nil,"This preset changed. Select it again before deleting." end
 if not writeSlot(d,slot,"") then return nil,"Delete failed: storage unavailable. Preset retained." end
 return {slot=slot,code=code}
end
function L.restoreDeleted(d,deleted)
 local slot=deleted.slot
 if d.presets["slot"..slot]~="" then
  slot=nil;for i=1,8 do if d.presets["slot"..i]=="" then slot=i;break end end
 end
 if not slot then return nil,"No free preset slots. Undo is retained; nothing was overwritten." end
 if not writeSlot(d,slot,deleted.code)then return nil,"Restore failed: storage unavailable."end
 return slot
end
function L.copy(d,session,name)
 local full=(name or session.name):match("^%s*(.-)%s*$")
 local base=full:sub(1,65)
 while #base>0 and #base<#full do
  local nextByte=full:byte(#base+1)
  if nextByte>=128 and nextByte<192 then base=base:sub(1,-2)else break end
 end
 if base=="" then return nil,"Enter a preset name." end
 local used={}
 for slot=1,8 do
  local preset=P.decode(d.presets["slot"..slot])
  if preset then used[preset.name:match("^%s*(.-)%s*$"):lower()]=true end
 end
 local copyName=base.." copy";local index=2
 while used[copyName:lower()]do copyName=base.." copy "..index;index=index+1 end
 local code,err=L.export(session,copyName)
 if not code then return nil,err end
 local copy=assert(L.open(code))
 local slot,saveError=L.save(d,copy,copyName)
 if not slot then return nil,saveError end
 return copy
end
function L.rename(d,slot,name)
 local session,err=L.open(d.presets["slot"..slot],slot)
 if not session then return nil,err end
 return L.save(d,session,name)
end
function L.load(d,code,reset)
 local preset,err=P.decode(code)
 if not preset then return nil,err end
 local undo=P.snapshot(d)
 P.apply(d,preset);reset()
 if not S.save(d) then return nil,"Loaded in memory, but storage failed.",undo end
 return preset.name,nil,undo
end
function L.import(text)
 local unpacked,transferError=require("src/core/presets").transfer.decode(text)
 if not unpacked then return nil,transferError end
 text=unpacked
 local preset,err=P.resolve(text)
 if not preset and type(text)=="string" and text:match("^%s*RS3ALERTS/2;") then
  preset,err=P.resolve(text:gsub("[\r\n]",""))
 end
 if not preset then return nil,err end
 return L.open(P.export(preset.settings,preset.name,preset.description))
end
return L
