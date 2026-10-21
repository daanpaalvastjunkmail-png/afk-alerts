local Wheel=require("src/ui/wheel")
local Quick=require("src/ui/quick_presets")
-- Compact monitor with a toolbar; detailed forms live in a larger editor.
local Trace=require("src/ui/trace")
local V=require("src/core/vars")
local S=require("src/core/settings")
local Editor=require("src/ui/settings_ui")
local Host=require("src/ui/settings_host")
local Visual=require("src/visual")
local P=require("src/core/presets")
local D={mode="list",rows={}}
local function flushVolume()
 if D.volumeDirty and D.context then S.save(D.context.d);D.volumeDirty=nil end
end
local function clear()
 Quick.unmount()
 D.volume=nil;D.volumeCaption=nil
 -- SimpleView adapters own hooks independently of their panel's raw component tree.
 for i=#(D.childViews or {}),1,-1 do V.safe(function() D.childViews[i]:Destroy() end) end
 D.childViews={}
 Visual.rows={}
 if D.view then V.safe(function() D.view:Destroy() end); D.view=nil end
 D.rows={}; D.nextUpdate=nil; D.list=nil; D.presetPanel=nil; D.presetDivider=nil; D.width=nil; D.height=nil
end
function D.destroy()
 flushVolume()
 Editor.destroy(); if D.limitView then V.safe(function() D.limitView:Destroy() end); D.limitView=nil end; Host.closeEditor(); clear(); D.context=nil; D.pending=nil; D.mode="list"; D.key=nil; D.draft=nil; D.refresh=nil; D.signature=nil; D.nextUpdate=nil; D.presetsOpen=false
end
function D.request(mode,key)
 if mode=="presets" then
  local library=require("src/ui/presets_ui");library.session=nil;library.alertDraft=nil;library.discardPending=nil;library.deletePending=nil;library.exportOnOpen=nil
 end
 if mode~="add" and mode~="edit" then D.draft=nil; D.draftKey=nil end
 D.pending={mode=mode,key=key}
end
local function save(d,reset,id)
 if not S.save(d) then return false end
 reset(id); return true
end
local function closeEditor()
 Editor.destroy()
 if D.limitView then V.safe(function() D.limitView:Destroy() end); D.limitView=nil end
 Host.closeEditor()
end
local function back() D.request("list") end
local function drawMuteSlash(parent,muted)
 if not muted then return end
 local c=ui.Canvas.new(parent);c:SetPos(73,1);c:SetSize(24,24);c.clickthrough=true
 c:AddLine(3,21,21,3,4,0x231D18FF)
 c:AddLine(3,21,21,3,2,0xFF7777FF)
end
local function drawPresetLines(toolbar,panel,width)
 local underline=ui.Canvas.new(toolbar.content);underline:SetPos(-54,25,1,0);underline:SetSize(44,2);underline.clickthrough=true
 underline:AddLine(0,0,44,0,1,0xD7BD7AFF)
 local line=ui.Canvas.new(panel.content);line:SetPos(4,-2,0,1);line:SetSize(-8,2,1,0);line.clickthrough=true
 line:AddLine(0,0,math.max(1,width-8),0,1,0x806B42FF)
 return line
end
function D.firing(key,now)
 local fired=Visual.lastFired and Visual.lastFired[key]
 return V.finite(now) and V.finite(fired) and now>=fired and now-fired<1.2
end
function D.summary(key,c,now)
 if not c.enabled then return "Paused" end
 local sample=Visual.samples and Visual.samples[key]
 local prefix=D.firing(key,now) and "ALERT · " or ""
 if sample and V.finite(sample.value) then
  if c.mode=="percent" and (not V.finite(sample.maximum) or sample.maximum<=0) then return "Maximum unavailable" end
  local value=sample.displayValue
  if not value and c.mode=="percent" and V.finite(sample.maximum) and sample.maximum>0 then
   value=string.format("%.1f%%",sample.value/sample.maximum*100)
  end
  value=value or string.format("%.1f",sample.value)
  return prefix..value
 end
 if c.type=="drop" then
  local status=Visual.sourceStatuses and Visual.sourceStatuses[key]
  return status or "Waiting for a matching owned ground-item drop"
 end
 if c.type=="buff" then return (Visual.sourceStatuses and Visual.sourceStatuses[key]) or "Waiting for effect data" end
 local sourceStatus=Visual.sourceStatuses and Visual.sourceStatuses[key]
 if sourceStatus then return sourceStatus end
 if c.type=="inventory" then return V.status.inventorySpace or V.errors.inventoryState or "Backpack data unavailable" end
 if c.type=="idle" then return "Waiting for "..c.skill.." XP" end
 if c.type=="chat" then return "Waiting for matching chat" end
 local unavailable={health="Health API unavailable",adrenaline="Adrenaline API unavailable",prayer="Prayer API unavailable",summoning="Summoning API unavailable",overload="Buff timer API unavailable",familiar="Familiar timer unavailable",antifire="Buff timer API unavailable",aggression="Buff timer API unavailable",buff="Buff timer API unavailable"}
 return unavailable[c.type] or "Waiting for live data"
end
-- Keep the monitor free of nested panel borders and their accumulated insets.
local function compactFont(button,large)
 local names=large and {"MUSEO_SANS_19PT_REGULAR","MUSEO_SANS_15PT_REGULAR","MUSEO_SANS_13PT_REGULAR"} or button and {"NOTOSANS_10","MUSEO_SANS_11PT_REGULAR"} or {"MUSEO_SANS_11PT_REGULAR","MUSEO_SANS_13PT_REGULAR"}
 for _,name in ipairs(names) do
  local ok,font=pcall(function() return id and id.Font and id.Font[name] end)
  if ok and font~=nil then return font end
 end
end
local function childView(parent,options)
 local view=prettyui.SimpleView.new(parent,options)
 D.childViews=D.childViews or {}; D.childViews[#D.childViews+1]=view
 return view
end
local function compactButton(view,label,action,options,large)
 -- SimpleButton uses its native stylesheet font. Draw a separate, smaller
 -- click-through label above an empty button so font choice actually applies.
 view:AddSimpleButton("",action,options)
 local text=view:AddText({text=label,font=compactFont(true,large),x=options.x,y=options.y,xAnchor=options.xAnchor,
  absolute=true,width=options.width,height=options.height,maxLines=1})
 text.clickthrough=true
 if text.AlignTo and ui.AlignMode then text:AlignTo(ui.AlignMode.CENTRE) end
end
local function renderList(parent,context)
 D.building=true
 local d=context.d
 Quick.sync(d)
 local font=compactFont()
 Trace.mark("monitor: toolbar")
 D.view=prettyui.SimpleView.new(parent,{width=parent.width,height=parent.height,scrollable=false,
  _onScrollWheel=function(component,delta)
   if D.list and D.list._onScrollWheel then return D.list._onScrollWheel(component,delta)end
   return true
  end})
 local toolbar=D.view
 compactButton(toolbar,"+",function() V.safe(function() D.draft=nil; D.request("add") end) end,
  {x=2,y=0,absolute=true,width=32,height=28,tooltip="Add an alert"},true)
 toolbar:AddSpriteButton("SETTINGS",function() V.safe(function() D.request("settings") end) end,
  {x=38,y=0,absolute=true,width=28,height=28,tooltip="Settings"})
 toolbar:AddSpriteButton("AUDIO",function() V.safe(function()
  d.masterMuted=not d.masterMuted
  if not S.save(d) then d.masterMuted=not d.masterMuted end
  D.request("list")
 end) end,{x=72,y=0,absolute=true,width=26,height=22,tooltip=d.masterMuted and "Unmute alerts" or "Mute alerts"})
 drawMuteSlash(toolbar.content,d.masterMuted)
 D.volume=toolbar:AddSlider({x=104,y=0,absolute=true,width=-174,widthAnchor=1,min=0,max=100,step=10,value=d.masterVolume,
  tooltip="Master volume: "..d.masterVolume.."% · all alerts",onChange=function(_,value)
   V.safe(function()
    if not V.finite(value) then return end
    d.masterVolume=math.floor(math.max(0,math.min(100,value))+0.5)
    D.volumeDirty=0
   end)
  end})
 D.volumeValue=d.masterVolume
 compactButton(toolbar,"Presets",function()V.safe(function()
  D.presetsOpen=not D.presetsOpen;D.refresh=true
 end)end,{x=-62,xAnchor=1,y=0,width=60,height=28,absolute=true,tooltip="Show / hide presets"})
 D.footerHeight=0
 D.listTop=36
 if D.presetsOpen then
  local panelHeight=Quick.height()
  D.presetPanel=childView(toolbar.content,{x=0,y=36,width=parent.width,height=panelHeight,scrollable=false})
  Quick.mount(D.presetPanel,d,context.reset,function()D.refresh=true end,font,function()
   D.presetsOpen=false
   D.request("presets")
   require("src/ui/presets_ui").shareExportOnOpen=true
  end)
  D.presetDivider=drawPresetLines(toolbar,D.presetPanel,parent.width)
  D.listTop=D.listTop+panelHeight+4
 end
 Trace.mark("monitor: scroll list")
 local list=childView(parent,{x=2,y=D.listTop,width=parent.width-4,height=math.max(60,parent.height-D.listTop-D.footerHeight),scrollable=true})
 D.list=list; D.width=parent.width; D.height=parent.height
 list:SetContentHeight(math.max(60,#d.entryOrder*60))
 local count=0
 for _,id in ipairs(d.entryOrder) do
  local c=d.entries[id]
  Trace.mark("monitor: row "..tostring(count+1))
  local row=childView(list.content,{x=0,y=count*60,width=list.content.width,height=60,scrollable=false,_onScrollWheel=Wheel.forward(list)})
  count=count+1
  local width=row.content.width
  local checkbox=row:AddCheckboxButton({{text="",value=id,selected=c.enabled}},
   {font=font,x=0,y=0,absolute=true,width=20,height=20,marginTop=0,marginBottom=0,onChange=function(_,_,_,selected)
    V.safe(function()
     local live=d.entries[id]
     if not D.building and live and type(selected)=="boolean" and live.enabled~=selected then
      live.enabled=selected
      if not save(d,context.reset,id) then live.enabled=not selected end
     end
    end)
   end})
  row:AddText({text=S.title(c),font=font,x=24,y=0,absolute=true,width=-146,widthAnchor=1,height=20,maxLines=1})
  compactButton(row,"Edit",function() V.safe(function() D.draft=nil; D.request("edit",id) end) end,
   {x=-116,xAnchor=1,y=0,absolute=true,width=38,height=22,tooltip="Edit"})
  compactButton(row,"Test",function() V.safe(function() context.test(id) end) end,
   {x=-74,xAnchor=1,y=0,absolute=true,width=40,height=22,tooltip="Test"})
  compactButton(row,"×",function() V.safe(function()
   local nextData=S.clone(d)
   S.remove(nextData,id)
   if not S.save(nextData) then return end
   S.remove(d,id); context.reset(id); D.refresh=true
  end) end,{x=-30,xAnchor=1,y=0,absolute=true,width=28,height=24,tooltip="Remove this alert from the current list"},true)
  local progress
  if c.visuals.bar then progress=V.safe(function()
   local canvas=ui.Canvas.new(row.content)
   canvas:SetPos(0,25); canvas:SetSize(math.max(1,width),7); canvas.clickthrough=true
   Wheel.bind(canvas,list)
   return canvas
  end) end
  local volume=row:AddSlider({x=-104,xAnchor=1,y=34,absolute=true,width=100,min=0,max=100,step=10,value=c.volume,
   tooltip="Alert volume: "..c.volume.."%",onChange=function(_,value)
    V.safe(function()
     local live=d.entries[id]
     if D.building or not live or not V.finite(value) then return end
     live.volume=math.floor(math.max(0,math.min(100,value))+0.5)
     D.volumeDirty=0
    end)
   end})
  local caption=row:AddText({text=D.summary(id,c,V.call("clock")),font=font,x=0,y=36,absolute=true,width=-110,widthAnchor=1,height=18,maxLines=1})
  D.rows[id]={caption=caption,captionColour=caption.colour,config=c,progress=progress,view=row,checkbox=checkbox,volume=volume,volumeValue=c.volume}
  Visual.rows=Visual.rows or {}; Visual.rows[id]=row.content
 end
 if count==0 then
  list:AddText({text="No alerts added yet.",font=font,height=18})
  list:AddText({text="+ Add alert · Presets at top right",font=font,height=36})
 end
 D.building=false
end
local function commit(context,draft,isNew,id)
 local nextData=S.clone(context.d)
 local target=id
 if isNew then
  local copy=S.clone(draft); copy.enabled=true
  local err
  target,err=S.add(nextData,copy.type,copy)
  if not target then return nil,err end
 elseif nextData.entries[id] then nextData.entries[id]=S.clone(draft)
 else return nil,"This alert no longer exists" end
 local ok,code=pcall(P.export,nextData,"Validation")
 if not ok then return nil,tostring(code) end
 local valid,err=P.decode(code)
 if not valid then return nil,err end
 nextData.storageReadError=nil
 if not S.save(nextData) then return nil,"Could not save. Your draft is retained; try Save again. "..tostring(V.status.storage or "") end
 local d=context.d
 d.entries=nextData.entries; d.entryOrder=nextData.entryOrder; d.nextID=nextData.nextID; d.storageReadError=nil
 context.reset(target)
 D.request("list")
 return true
end
local function render(parent,context)
 if D.mode=="list" then return end
 local options={back=back}
 if D.mode=="add" then
  if #context.d.entryOrder>=S.maxEntries then
   D.limitView=prettyui.SimpleView.new(parent,{width=parent.width,height=parent.height})
   D.limitView:AddSimpleButton("Back to alerts",back); D.limitView:AddText("This list has the maximum of 32 alerts. Remove one before adding another."); return
  end
  local kind=D.key or (D.draft and D.draft.type) or "health"
  if not D.draft or D.draft.type~=kind then D.draft=S.newAlert(kind) end
  options.draft=D.draft; options.isNew=true
  options.changeType=function(typeName) D.request("add",typeName) end
  options.commit=function(c) return commit(context,c,true) end
 elseif D.mode=="edit" then
  if not context.d.entries[D.key] then D.request("list"); return end
  if not D.draft or D.draftKey~=D.key then D.draft=S.clone(context.d.entries[D.key]); D.draftKey=D.key end
  options.draft=D.draft
  options.commit=function(c) return commit(context,c,false,D.key) end
 elseif D.mode=="presets" then options.section="presets";options.compactPresets=true; options.highlights=function() D.request("highlights") end
 elseif D.mode=="highlights" then options.section="highlights"; options.back=function() D.request("presets") end end
 Editor.mount(parent,context.d,context.test,context.reset,context.testSound,options)
end
local function listSignature(d)
 local signature={tostring(d.masterMuted)}
 for _,id in ipairs(d.entryOrder) do
  local c=d.entries[id]
  signature[#signature+1]=id..":"..S.title(c)..":"..tostring(c.visuals.bar)
 end
 return table.concat(signature,"|")
end
function D.mount(parent,d,test,reset,testSound)
 D.destroy()
 D.context={parent=parent,d=d,test=test,reset=reset,testSound=testSound}
 renderList(parent,D.context)
 D.signature=listSignature(d)
 D.quickActivation=Quick.activation
end
local function refreshList(context)
 local scroll=D.list and D.list.scrollY or 0
 clear()
 context.parent=Host.setMode("list",context.d)
 renderList(context.parent,context)
 D.list:SetScrollPosition(scroll)
 D.refresh=nil
end
function D.tick()
 if V.uiBlocked then return end
 local context=D.context
 if not context then return end
 if D.volumeDirty then
  D.volumeDirty=D.volumeDirty+1
  if D.volumeDirty>=25 then flushVolume() end
 end
 if D.volume and D.volumeValue~=context.d.masterVolume then
  D.volumeValue=context.d.masterVolume
  D.volume:SetValue(D.volumeValue,false)
  D.volume:SetTooltip("Master volume: "..D.volumeValue.."% · all alerts")
 end
 if D.pending then
  local nextView=D.pending; D.pending=nil
  closeEditor()
  D.mode=nextView.mode; D.key=nextView.key
  if D.mode=="list" then D.refresh=true
  else
   local ok,err=pcall(function()
    local parent=Host.setMode(D.mode,context.d,back)
    render(parent,context)
   end)
   if not ok then
    -- Clear the consumed request and incomplete editor; no automatic retries.
    V.noteUIError(err);V.report("settings.open",err)
    closeEditor();D.mode="list"
    V.status.settingsWindow="Editor could not be opened. Monitor retained; see developer console."
   end
  end
 end
 Editor.tick()
 if Quick.sync(context.d) then D.refresh=true end
 if D.quickActivation~=Quick.activation then
  D.quickActivation=Quick.activation
  if D.presetsOpen then D.presetsOpen=false;D.refresh=true end
  if D.mode~="list" then D.request("list")end
 end
 -- Resize existing views and canvases; dragging never rebuilds native controls.
 local parent=context.parent
 if D.list and (parent.width~=D.width or parent.height~=D.height) then
  D.width=parent.width; D.height=parent.height
  D.view:SetSize(parent.width,parent.height)
  if D.presetPanel then
   local panelHeight=Quick.height();D.presetPanel:SetSize(parent.width,panelHeight)
   if D.presetDivider then D.presetDivider:Clear();D.presetDivider:AddLine(0,0,math.max(1,parent.width-8),0,1,0x806B42FF)end
  end
  D.list:SetSize(math.max(1,parent.width-4),math.max(60,parent.height-(D.listTop or 36)-(D.footerHeight or 0)))
  D.list:SetContentHeight(math.max(60,#context.d.entryOrder*60))
  for _,row in pairs(D.rows) do
   local width=math.max(1,D.list.content.width)
   row.view:SetSize(width,60)
   if row.progress then row.progress:SetSize(width,7) end
  end
 end
 -- Preset application also replaces entries/order; detect it independently of editor mode.
 local signature=listSignature(context.d)
 if D.refresh or signature~=D.signature then
  D.refresh=nil; D.signature=signature
  local ok,err=pcall(refreshList,context)
  D.building=false
  if not ok then
   V.noteUIError(err)
   V.report("monitor",err)
   V.status.monitor="List rendering failed; reopen AFK ALERTS from the Plugins ribbon to retry. Alert settings retained."
   -- Keep the saved entries available even when a native row control fails.
   clear()
   if V.uiBlocked then return end
   V.safe(function()
    D.view=prettyui.SimpleView.new(context.parent,{width=context.parent.width,height=context.parent.height})
    D.view:AddText("Your alerts are saved. The detailed list could not be drawn.")
    for _,id in ipairs(context.d.entryOrder) do D.view:AddText(S.title(context.d.entries[id])) end
    D.view:AddText("Reopen AFK ALERTS from the Plugins ribbon to retry. Console: "..tostring(err):sub(1,180))
   end)
  else V.status.monitor="Ready" end
 end
 local now=V.call("clock")
 if V.finite(now) and D.nextUpdate and now>=D.nextUpdate-1 and now<D.nextUpdate then return end
 D.nextUpdate=V.finite(now) and now+0.2 or nil
 for key,row in pairs(D.rows) do
  local c=context.d.entries[key]
  if c then
   row.config=c
   if row.checkbox then row.checkbox:SetSelected(key,c.enabled,false) end
   if row.volume and row.volumeValue~=c.volume then
    row.volumeValue=c.volume
    row.volume:SetValue(c.volume,false)
    row.volume:SetTooltip("Alert volume: "..c.volume.."%")
   end
   local summary=D.summary(key,c,now)
   if row.lastSummary~=summary then
    local ok,err=pcall(function() row.caption.content=summary end)
    if ok then row.lastSummary=summary else V.report("monitor.status",err) end
   end
   local firing=D.firing(key,now)
   if row.lastFiring~=firing then
    row.lastFiring=firing
    if Vector4 and Vector4.new then V.safe(function()
     row.caption.colour=firing and Vector4.new(1,0.84,0.30,1) or row.captionColour or Vector4.new(0.77,0.73,0.62,1)
    end)end
   end
   if row.progress then V.safe(function()
    local canvas=row.progress; local sample=Visual.samples and Visual.samples[key]
    local ratio=0
    if sample and V.finite(sample.value) then
     local maximum=sample.maximum or c.reference
     if V.finite(maximum) and maximum>0 then ratio=math.max(0,math.min(1,sample.value/maximum)) end
    end
    local width=math.max(1,canvas.width)
    local filled=c.enabled and math.floor(width*ratio) or 0
    local triggered=c.enabled and sample and V.finite(sample.value) and Visual.conditions and Visual.conditions[key]==true
    local colour=triggered and 0xEE5544FF or 0x55BBAAFF
    local background=triggered and 0xA63832FF or 0x252B33FF
    if row.lastWidth==width and row.lastFilled==filled and row.lastColour==colour and row.lastBackground==background then return end
    -- Cache before calling native methods: failed canvases do not spin every tick.
    row.lastWidth=width; row.lastFilled=filled; row.lastColour=colour;row.lastBackground=background
    canvas:Clear()
    canvas:AddRectangle(0,0,width,7,background)
    if filled>0 then
     canvas:AddRectangle(0,0,filled,7,colour)
    end
   end) end
  end
 end
end
return D
