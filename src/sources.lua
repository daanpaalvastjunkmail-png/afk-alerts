local V=require("src/core/vars")
local R={previous=nil,pending={},drop=nil,lootPending={},lootSequence=0,lootAcceptAfter=0,lootBatches={},lootSignature=nil}
function R.new()
 return setmetatable({previous=nil,pending={},drop=nil,lootPending={},lootSequence=0,lootAcceptAfter=0,lootBatches={}}, {__index=function(_,key) local value=R[key]; if type(value)=="function" then return value end end})
end
function R:inventory()
 local slots=V.call("inventory")
 if type(slots)~="table" then self.previous=nil; return end
 local totals={}
 for _,s in pairs(slots) do
  if type(s)~="table" then self.previous=nil; return end
  local count=s.count or s.amount
  if s.id and s.id>=0 then
   if not V.finite(count) or count<0 then self.previous=nil; return end
   totals[s.id]=(totals[s.id] or 0)+count
  end
 end
 if self.previous then
  for item,n in pairs(totals) do
   local delta=n-(self.previous[item] or 0)
   if delta>0 then self.pending[item]=(self.pending[item] or 0)+delta end
  end
 end
 self.previous=totals
end
-- Internal normalized ground-item input; fields come from documented ObjStack events.
function R:resetLoot(now)
 self.lootPending={}; self.lootBatches={}; self.drop=nil; self.dropStatus=nil;self.lootAcceptAfter=now+3
end
function R:groundLoot(event,kind,now)
 if not event or event.isOwner~=true or not V.finite(now) or now<self.lootAcceptAfter then return false end
 local obj=event.objType
 if not obj or not V.finite(obj.id) or obj.id<0 then return false end
 local count=event.count
 if kind=="changed" then
  if not V.finite(event.oldCount) or not V.finite(event.newCount) then return false end
  count=event.newCount-event.oldCount
 end
 if not V.finite(count) or count<=0 then return false end
 local entry=self.lootPending[obj.id] or {count=0,name=obj.name or tostring(obj.id),baseCost=obj.cost,tradeable=obj.isStockmarket}
 entry.count=entry.count+count
 self.lootPending[obj.id]=entry
 return true
end
function R:chatMessage(event,c,now)
 if not V.finite(now) then return false end
 local matches,message=require("src/chat").matches(event,c)
 if not matches then return false end
 if self.chatLast and now>=self.chatLast and now-self.chatLast<c.cooldown then return false end
 self.chatLast=now; self.chatSequence=(self.chatSequence or 0)+1
 self.chatSample={value=1,maximum=1,eventID=self.chatSequence,message=message,displayValue="Matched: "..message}
 self.chatExpires=now+c.duration
 return true
end
function R:resetActivity() self.activity=nil end
function R:read(key,c,now)
 if key=="chat" then
  if not require("src/chat").permission() then self.chatSample=nil; return nil,V.status.chat end
  if self.chatSample and now<self.chatExpires then return self.chatSample end
  self.chatSample=nil
  return nil,V.status["event.ChatMessage"]=="Unavailable" and "Chat event unavailable; retrying" or "Waiting for matching chat"
 end
 if key=="idle" then
  local xp=V.call("skillXP",c.skill)
  if not V.finite(xp) or not V.finite(now) then self:resetActivity(); return nil end
  local a=self.activity
  if not a or a.skill~=c.skill or now<a.time or xp<a.xp then
   self.activity={skill=c.skill,xp=xp,time=now,armed=false}; return nil
  end
  if xp>a.xp then a.armed=true; a.time=now; a.xp=xp end
  if not a.armed then V.status.activity="Waiting for the first XP gain in "..c.skill; return nil end
  local elapsed=now-a.time
  V.status.activity=string.format("%s: %.0f seconds since XP",c.skill,elapsed)
  return {value=elapsed,maximum=c.reference,message=string.format("No %s XP for %.0f seconds",c.skill,elapsed),displayValue=string.format("%.0f seconds without XP",elapsed)}
 end
 if key=="inventory" then
  local used,total=V.call("inventoryState")
  if not V.finite(used) or not V.finite(total) or total<=0 or used<0 or used>total then
   V.status.inventorySpace=V.errors.inventoryState or V.status.inventorySpace or "Backpack data unavailable"
   return nil
  end
  V.status.inventorySpace=string.format("%.0f / %.0f slots used",used,total)
  return {value=used,maximum=total,message=string.format("Inventory: %.0f / %.0f slots used",used,total),displayValue=string.format("%.0f / %.0f slots",used,total)}
 end
 if key=="drop" then
  if c.lootSource~="owned_ground" then
   self.lootPending={}; self.lootBatches={}; self.drop=nil
   V.status.targetLoot="Unavailable: source NPC attribution is not exposed by the documented events"
   return nil,V.status.targetLoot
  end
  V.status.targetLoot="Owned ground-item fallback; source NPC is not verified"
  local filter=(c.itemNameFilter or ""):match("^%s*(.-)%s*$"):lower()
  local signature=c.lootSource..":"..c.dropMetric..":"..filter
  if self.lootSignature and self.lootSignature~=signature then self.lootBatches={}; self.drop=nil;self.dropStatus=nil end
  self.lootSignature=signature
  local items={}
  for item,entry in pairs(self.lootPending) do
   if filter=="" or entry.name:match("^%s*(.-)%s*$"):lower()==filter then items[item]=entry end
  end
  self.lootPending={}
  if next(items) then
   self.lootSequence=self.lootSequence+1
   if #self.lootBatches<100 then
    self.lootBatches[#self.lootBatches+1]={items=items,eventID=self.lootSequence,deadline=now+60}
   else V.report("loot","Too many pending loot batches; newest batch was skipped") end
  end
  local status=self.dropStatus
  local batch=self.lootBatches[1]
  if batch then
   local quantity,value,known,approximate=0,0,true,false
   local names={}
   for item,entry in pairs(batch.items) do
    quantity=quantity+entry.count
    names[#names+1]=entry.name.." x"..entry.count
    if c.dropMetric~="count" then
     local price,info=V.call("price",item,c.dropMetric,entry)
     if V.finite(price) and price>=0 then
      approximate=approximate or info==true
      local subtotal=price*1.0*entry.count
      if V.finite(subtotal) and subtotal>=0 and value+subtotal<=9007199254740991 then value=value+subtotal
      else known=false; V.status.prices="Loot value exceeds the supported numeric range";status=V.status.prices end
     else
      known=false
      status=type(info)=="string" and info or V.errors.price or V.status.prices or "Price unavailable"
     end
    end
   end
   if known then
    status=nil
    table.remove(self.lootBatches,1); table.sort(names)
    local label=c.dropMetric=="ge" and "GE" or c.dropMetric=="high_alch" and "High Alch" or nil
    local total=label and ((approximate and "≈ " or "")..string.format("%.0f gp",value)) or tostring(quantity).." items"
    local message=table.concat(names,", ")
    if label then message=message.." · "..label..": "..total end
    self.drop={value=label and value or quantity,expires=now+c.duration,eventID=batch.eventID,
     message=message,displayValue=label and (label..": "..total) or total}
   elseif now>=batch.deadline then
    table.remove(self.lootBatches,1)
    status="Loot price unavailable after 60 seconds: "..tostring(status or "No price response")
    V.report("lootPrice",status)
   end
  end
  self.dropStatus=status
  local drop=self.drop
  if not drop or now>=drop.expires then
   self.drop=nil
   return nil,status or "Waiting for a matching owned ground-item drop"
  end
  return {value=drop.value,maximum=c.reference,eventID=drop.eventID,message=drop.message,displayValue=drop.displayValue}
 end
 if key=="skill" then
  local value,maximum=V.call("skill",c.skill)
  return {value=value,maximum=maximum}
 end
 if key=="overload" then
  self.overloadState=self.overloadState or {}
  local sample=require("src/overloads").read(now,c,self.overloadState)
  return sample,V.status.overload
 end
 if key=="familiar" or key=="antifire" or key=="aggression" or key=="buff" then
  self.timerState=self.timerState or {}
  local sample=require("src/timers").read(key,c,now,self.timerState)
  return sample,V.status[key]
 end
 local names=V.names[key]
 if names then
  local maximum
  if names[2] then maximum=V.call("readVar",names[2])
  elseif key=="adrenaline" then maximum=1000
  elseif key=="prayer" or key=="summoning" then
   local _,level=V.call("skill",key=="prayer" and "PRAYER" or "SUMMONING")
   if V.finite(level) and level>0 then maximum=level*10 end
  end
  local value=V.call("readVar",names[1])
  if key=="health" then
   if not V.finite(value) or value<0 then V.status.health="Health unavailable"; return nil end
   if not V.finite(maximum) or maximum<=0 then
    V.status.health="Maximum health unavailable"
    return {value=value}
   end
   local label=string.format("%.0f / %.0f HP · %.1f%%",value,maximum,value/maximum*100)
   V.status.health=label
   return {value=value,maximum=maximum,displayValue=label}
  end
  if not V.finite(value) or value<0 then V.status[key]="Unavailable"; return nil end
  if key=="prayer" then value=math.floor(value/10) end
  if key=="adrenaline" then
   -- 1000 raw points is the standard 100% mark, not a hard cap.
   value=value/10; maximum=100
  end
  local label
  if key=="adrenaline" then label=string.format("%.1f%% adrenaline",value)
  elseif V.finite(maximum) and maximum>0 then
   label=string.format("%.0f / %.0f · %.1f%%",value,maximum,value/maximum*100)
  else label=string.format("%.0f · maximum unavailable",value) end
  V.status[key]=label
  return {value=value,maximum=maximum,displayValue=label}
 end
end
return R
