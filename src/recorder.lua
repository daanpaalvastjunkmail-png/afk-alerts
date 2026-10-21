-- Opt-in bounded diagnostic recorder. No gameplay actions, chat/account reads,
-- network transfer, UI creation or automatic effect-binding changes.
local V=require("src/core/vars")
local R={running=false,maxBytes=48000,maxSeconds=1200,readsPerTick=12,interval=2,key="rs3_alerts.recording.v1"}
local function status(text) V.status.recording=text end
local function available()
 local ok,value=pcall(function() return Player.IsAvailable() end)
 return ok and value==true
end
function R.start(now)
 if R.running then return false end
 if not V.finite(now) or not available() then status("Log into a world before starting"); return false end
 R.catalog=require("src/recording_catalog")
 R.running=true;R.started=now;R.lastTime=now;R.nextRound=now;R.cursor=nil
 R.lines={"RS3DIAG/1","START,"..tostring(now)};R.bytes=#table.concat(R.lines,"\n")+1
 R.previous={};R.seenIDs={};R.gap=false;R.changes=0
 status("Recording numeric effect changes; play normally, then Stop and Show recording")
 return true
end
local function append(line)
 if R.bytes+#line+1>R.maxBytes-100 then return false end
 R.lines[#R.lines+1]=line;R.bytes=R.bytes+#line+1;return true
end
function R.stop(reason)
 if not R.running then return false end
 R.running=false
 R.lines[#R.lines+1]="STOP,"..tostring(R.lastTime)..","..(reason or "manual")
 R.result=table.concat(R.lines,"\n")
 local saved=true
 if PersistentDB then
  -- Small DB strings avoid one very large storage write. Metadata is committed last.
  local ok,value=pcall(function()
   local active=PersistentDB:GetString(R.key..".active")
   local bank=active=="a" and "b" or "a"
   local prefix=R.key.."."..bank
   local chunks=math.ceil(#R.result/16000)
   for i=1,chunks do
    if PersistentDB:SetString(prefix.."."..i,R.result:sub((i-1)*16000+1,i*16000))~=true then return false end
   end
   if PersistentDB:SetString(prefix..".count",tostring(chunks))~=true then return false end
   return PersistentDB:SetString(R.key..".active",bank)==true
  end)
  saved=ok and value
 else saved=false end
 status("Stopped: "..R.changes.." changes, "..#R.result.." bytes. "..(saved and "Saved locally; click Show recording" or "Kept in memory; click Show recording before reloading"))
 return true
end
local function rawExport()
 if R.running then return nil,"Stop recording first" end
 if R.result then return R.result end
 local ok,value=pcall(function()
  local bank=PersistentDB:GetString(R.key..".active")
  if bank~="a" and bank~="b" then return nil end
  local prefix=R.key.."."..bank
  local count=tonumber(PersistentDB:GetString(prefix..".count"))
  if not count or count%1~=0 or count<1 or count>3 then return nil end
  local parts={}
  for i=1,count do
   parts[i]=PersistentDB:GetString(prefix.."."..i)
   if type(parts[i])~="string" or #parts[i]>16000 then return nil end
  end
  local data=table.concat(parts)
  if #data>R.maxBytes or data:sub(1,9)~="RS3DIAG/1" then return nil end
  return data
 end)
 if ok and value then R.result=value;return value end
 return nil,"No saved recording yet"
end
function R.export()
 local data,err=rawExport()
 if not data then return nil,err end
 -- The native export field is single-line: never put raw newline records in it.
 if type(data)~="string" or #data>R.maxBytes or
    not data:match("^RS3DIAG/1\nSTART,[^\n]+\n") or not data:match("\nSTOP,[^\n]+$") then
  return nil,"Saved recording is incomplete; start a new recording"
 end
 return "RS3DIAG/2;"..data:sub(11):gsub("\n",";")
end
function R.tick(now)
 if not R.running or not V.finite(now) then return end
 if now<R.lastTime then R.stop("clock-reset");return end
 R.lastTime=now
 if now-R.started>=R.maxSeconds then R.stop("time-limit");return end
 if not available() then
  if not R.gap then
   if not append("GAP,"..tostring(now)) then R.stop("size-limit");return end
   R.gap=true;R.previous={};R.cursor=nil
  end
  return
 end
 if R.gap then R.gap=false;R.nextRound=now end
 if not R.cursor then
  if now<R.nextRound then return end
  R.cursor=1;R.nextRound=now+R.interval
 end
 for _=1,R.readsPerTick do
  local index=R.cursor;local item=R.catalog[index]
  if not item then R.cursor=nil;return end
  R.cursor=index+1
  local ok,value=pcall(function()
   local scope=item.domain=="C" and var.VarClient or var.VarPlayer
   return scope[item.name].value
  end)
  if ok and V.finite(value) then
   local previous=R.previous[index]
   -- Initial inactive client effects are omitted; modifiers include their zero baseline.
   if value~=previous and (previous~=nil or item.domain=="P" or value>0) then
    local dictionary=not R.seenIDs[index] and string.format("D,%d,%s,%d,%s",index,item.domain,item.id,item.name) or nil
    local event=string.format("V,%.2f,%d,%.17g",now,index,value)
    local extra=#event+1+(dictionary and #dictionary+1 or 0)
    if R.bytes+extra>R.maxBytes-100 then R.stop("size-limit");return end
    if dictionary then append(dictionary);R.seenIDs[index]=true end
    append(event);R.changes=R.changes+1
   end
   R.previous[index]=value
  else
   -- Signal lost data once, not a fabricated timer expiration.
   if R.previous[index]~=nil and R.seenIDs[index] then
    if not append(string.format("M,%.2f,%d",now,index)) then R.stop("size-limit");return end
   end
   R.previous[index]=nil
  end
 end
end
return R
