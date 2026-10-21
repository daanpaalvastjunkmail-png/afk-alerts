-- Client adapters based on the official documentation saved locally.
local V=require("src/core/vars")
local H={canvas=nil,seconds=0}
local function round(n) return math.floor(n+0.5) end
-- The saved API docs disagree between valid (property table) and isValid
-- (warning text). Read each defensively and support either boolean form.
local function field(object,name)
 local ok,value=pcall(function()return object[name]end)
 if ok then return value end
end
local function backpack()
 local inv=Inventory.Find(config.Inv.INV)
 if not inv then V.status.inventorySpace="Backpack data unavailable";return nil end
 local valid=field(inv,"valid")
 if valid==nil then valid=field(inv,"isValid") end
 if valid~=true then V.status.inventorySpace="Backpack validity unavailable";return nil end
 return inv
end
function H.install()
 V.adapters.clock=function() return H.seconds end
 V.adapters.gameArea=function()
  return ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
 end
 V.adapters.readVar=function(name)
  if not Player.IsAvailable() then return nil end
  local entry=var.VarPlayer[name]
  if entry then return entry.value end
 end
 V.adapters.readClientVar=function(name)
  if not Player.IsAvailable() then return nil end
  local clients=var and var.VarClient
  local entry=clients and clients[name]
  if entry then return entry.value end
 end
 V.adapters.buffs=function() return require("src/timers").effects("overload",H.seconds) end
 V.adapters.skill=function(name)
  if not Player.IsAvailable() then return nil end
  local skill=SkillType[name]
  if skill==nil then return nil end
  return Player.GetLevelGameplay(skill),Player.GetLevelCapped(skill)
 end
 V.adapters.skillXP=function(name)
  if not Player.IsAvailable() then return nil end
  local skill=SkillType[name]
  if skill==nil then return nil end
  return Player.GetXPUncapped(skill)
 end
 V.adapters.inventoryState=function()
  if not Player.IsAvailable() then return nil end
  local inv=backpack()
  if not inv then return nil end
  local total,used=field(inv,"slotCount"),field(inv,"usedSlotCount")
  if not V.finite(total) or total<=0 then V.status.inventorySpace="Backpack capacity unavailable";return nil end
  if not V.finite(used) or used<0 or used>total then
   local slots=inv:GetSlots()
   if type(slots)~="table" then V.status.inventorySpace="Backpack slots unavailable";return nil end
   used=0
   for _,slot in pairs(slots) do
    if slot.obj and V.finite(slot.count) and slot.count>0 then used=used+1 end
   end
  end
  return used,total
 end
 V.adapters.inventory=function()
  if not Player.IsAvailable() then return nil end
  local inv=backpack()
  if not inv then return nil end
  local slots=inv:GetSlots()
  if not slots then return nil end
  local result={}
  for _,slot in pairs(slots) do
   if slot.obj then result[#result+1]={id=slot.obj.id,count=slot.count} end
  end
  return result
 end
 V.adapters.audio=function(path,volume,channel)
  local stem,extension=path:match("^sounds/(.+)%.([^%.]+)$")
  if not extension or (extension:lower()~="mp3" and extension:lower()~="ogg") then stem=nil end
  local resources=Plugin.resources
  local nested=resources and resources.sounds
  local resource=stem and ((nested and nested[stem]) or (resources and resources["alert_"..stem]))
  if not resource then
   error("OGG resource not discovered for "..tostring(stem)..". Disable the plugin, run prf, then enable it again to refresh resources.")
  end
  local params=audio.SoundPlaybackParams.new()
  params.type=audio.SoundType.SCRIPT
  params.audioBus=audio.AudioBus[channel or "MASTER"] or audio.AudioBus.MASTER or audio.AudioBus.SFX
  params.volume=volume
  params.numLoops=0
  params.emitterShape=audio.EmitterShape.NONE
  local sound=audio.Play(resource,params)
  if not sound then error("Audio resource could not be played") end
  return sound
 end
 -- Cursor pixels are not yet converted to UI units by the documented API.
 -- Use the fixed popup position until cursor scaling is verified.
 V.status.mouse="Fixed popup: cursor scaling not verified"
 V.adapters.rect=function(x,y,w,h,c)
  if H.canvas then H.canvas:AddRectangle(round(x),round(y),round(w),round(h),c); return true end
 end
 V.adapters.text=function(x,y,text,c,width)
  if not H.canvas then return end
  local cfg=ui.TextDataConfig.new()
  cfg.font=id.Font.MUSEO_SANS_15PT_REGULAR
  cfg.alignHorizontal=ui.AlignMode.CENTRE
  cfg.alignVertical=ui.AlignMode.CENTRE
  cfg.colour=Vector4.new(((c>>24)&255)/255,((c>>16)&255)/255,((c>>8)&255)/255,(c&255)/255)
  H.canvas:AddText(round(x),round(y),round(width or 560),28,text,cfg)
  return true
 end
 V.adapters.popupInput=function(enabled,onClick)
  if not H.dismissLayer and enabled then
   local area=V.call("gameArea")
   if not area then return end
   local layer=ui.Layer.new(area)
   H.dismissLayer=layer
   layer:SetPos(0,0);layer:SetSize(0,0,1,1)
   layer.clickthrough=true
   layer:Subscribe(ui.Hook.ONCLICK,function()onClick();return true end)
   H.dismissLayer=layer
  end
  if H.dismissLayer then
   H.dismissLayer.hidden=not enabled
   if enabled then H.dismissLayer:MoveToFront() end
  end
 end
 V.adapters.circle=function(x,y,r,c)
  if not H.canvas then return end
  for i=0,47 do
   local a,b=i*math.pi/24,(i+1)*math.pi/24
   H.canvas:AddLine(round(x+math.cos(a)*r),round(y+math.sin(a)*r),round(x+math.cos(b)*r),round(y+math.sin(b)*r),3,c)
  end
  return true
 end
end
function H.beginFrame()
 if V.uiBlocked or H.canvasUnavailable then return end
 local parent=V.call("gameArea")
 if not parent then return end
 if not H.canvas then
  local ok,canvas=pcall(function() return ui.Canvas.new(parent) end)
  if not ok or not canvas then
   H.canvasUnavailable=true
   V.noteUIError(canvas)
   V.report("overlay",canvas or "Overlay canvas unavailable; reopen the client to retry")
   return
  end
  H.canvas=canvas
  H.canvas:SetPos(0,0)
  H.canvas.clickthrough=true
 end
 H.canvas:SetSize(parent.width,parent.height)
 H.canvas:Clear()
 if H.canvas.MoveToFront then H.canvas:MoveToFront() end
end
function H.destroy()
 if H.dismissLayer then V.safe(function()H.dismissLayer:Destroy()end);H.dismissLayer=nil end
 if H.canvas then V.safe(function() H.canvas:Destroy() end); H.canvas=nil end
end
return H
