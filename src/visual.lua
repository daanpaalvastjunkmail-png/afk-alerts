local V=require("src/core/vars")
local S=require("src/core/settings")
local M={active={},bars={},conditions={},lastFired={}}
function M.position(c,area)
 local x=c.bar.x
 if c.position=="top_center" and area then x=math.max(0,math.floor((area.width-260)/2+c.bar.x)) end
 return x,c.bar.y
end
function M.dismissPopups()
 for _,alert in pairs(M.active)do alert.popupDismissed=true end
end
function M.message(c,sample)
 if c.type=="inventory" then return "Inventory full" end
 if c.type=="idle" then return "Skilling stopped" end
 if c.type=="drop" then return "Loot drop" end
 if c.type=="health" then return c.direction=="below" and "Low health" or "Health target reached" end
 if c.type=="prayer" then return c.direction=="below" and "Low prayer" or "Prayer target reached" end
 if c.type=="adrenaline" then return c.direction=="below" and "Low adrenaline" or "Adrenaline target reached" end
 if c.type=="summoning" then return c.direction=="below" and "Low Summoning points" or "Summoning target reached" end
 if c.type=="buff" then
  if sample.presenceOnly then return sample.message or sample.displayValue or "Effect missing on NPC target" end
  local label="Buff"
  for _,option in ipairs(require("src/timers").options)do if option.id==c.buffID then label=option.label end end
  if c.direction=="above" then
   if c.mode=="absolute" and c.threshold==0 then return c.name~="" and c.name or (label.." active") end
   return label.." threshold reached"
  end
  return label..(sample.value==0 and " expired" or " expires soon")
 end
 return sample.message or (c.name~="" and c.name) or (c.label.." alert")
end
function M.emit(key,c,sample,now) M.lastFired[key]=now;M.active[key]={untilTime=now+c.duration,sample=sample,config=c} end
function M.draw(settings,now)
 local area=V.call("gameArea")
 local pulse=(math.sin(now*9)+1)/2
 -- Draw the flash before text and circles to keep them readable.
 local flash=false
 local popupIndex=0
 for key,a in pairs(M.active) do
  local c=a.config or settings.entries[key]
  if c and now<a.untilTime and c.visuals.flash then flash=true end
 end
 if flash and area then V.call("rect",0,0,area.width,area.height,0xFF330000+math.floor(55*pulse)) end
 local order=S.clone(settings.entryOrder)
 local known={}; for _,id in ipairs(order) do known[id]=true end
 for id in pairs(M.active) do if not known[id] then order[#order+1]=id end end
 for i,key in ipairs(order) do
  local a=M.active[key]
  local c=a and a.config or settings.entries[key]
  if c then
  if a and now>=a.untilTime and not (c.visuals.popup and not a.popupDismissed) then M.active[key]=nil; a=nil end
  if a then
   if c.visuals.popup and not a.popupDismissed and area then
    local width=math.max(100,math.min(560,area.width-32))
    local x=math.max(0,math.floor((area.width-width)/2))
    local y=48+popupIndex*104
    popupIndex=popupIndex+1
    V.call("rect",x,y,width,94,0x171B22F2)
    V.call("rect",x,y,width,4,0xE9B44CFF)
    V.call("text",x+12,y+8,M.message(c,a.sample),0xFFFFFFFF,width-24)
    V.call("text",x+12,y+34,(c.type=="drop" and a.sample.message) or a.sample.displayValue or a.sample.message or "Alert triggered",0xE5DCC8FF,width-24)
    V.call("text",x+12,y+62,"Click anywhere to dismiss",0xB8BEC8FF,width-24)
   end
   if c.visuals.flash then flash=true end
   if now<a.untilTime and c.visuals.circle and pulse>0.45 then
    local row=M.rows and M.rows[key]
    local component=row and V.safe(function()
     local pos=row.xyGlobal
     return {x=pos.x,y=pos.y,width=row.width,height=row.height}
    end)
    if type(component)=="table" then
     local x,y=component.x+component.width/2,component.y+component.height/2
     V.call("circle",x,y,math.max(component.width,component.height)/2+8,0xFF5533FF)
    end
   end
  end
  end
 end
 V.call("popupInput",popupIndex>0,M.dismissPopups)
end
function M.clear(key)
 M.active[key]=nil;M.conditions[key]=nil;M.lastFired[key]=nil
 if M.samples then M.samples[key]=nil end
 if M.bars[key] then V.safe(function() M.bars[key].window:Destroy() end); M.bars[key]=nil end
end
function M.destroy()
 for _,b in pairs(M.bars) do V.safe(function() b.window:Destroy() end) end
 M.bars={}; M.active={};M.conditions={};M.lastFired={}
end
return M
