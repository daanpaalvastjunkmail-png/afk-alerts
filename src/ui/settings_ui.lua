local V=require("src/core/vars")
local S=require("src/core/settings")
local A=require("src/audio")
local Chat=require("src/chat")
local PresetsUI=require("src/ui/presets_ui")
local Catalog=require("src/core/alert_catalog")
local Wheel=require("src/ui/wheel")
local U={}
function U.destroy()
 for i=#(U.children or {}),1,-1 do local child=U.children[i];V.safe(function()child:Destroy()end)end
 U.children=nil;U.rebuildInputs=nil
 U.chatLog=nil;U.alertSearch=nil
 U.geStatus=nil;U.lastGEStatus=nil
 U.permissionRows=nil;U.permissionNote=nil;U.lastPermissionNote=nil
 if U.footer then V.safe(function()U.footer:Destroy()end);U.footer=nil end
 U.columns=nil
 if U.view then V.safe(function() U.view:Destroy() end); U.view=nil end
 U.layout=nil; U.context=nil; U.remount=nil; U.width=nil; U.height=nil;U.resizeWidth=nil;U.resizeHeight=nil;U.resizeQuiet=nil
end
function U.tick()
 for _,row in ipairs(U.permissionRows or {})do
  local message=V.permissionStatus(row.name,row.label)
  if message~=row.last then row.control.content=message;row.last=message end
 end
 if U.permissionNote then
  local message=V.status.permissions or "Open Plugin Hub > AFK ALERTS > padlock to manage optional permissions."
  if message~=U.lastPermissionNote then U.permissionNote.content=message;U.lastPermissionNote=message end
 end
 if U.alertSearch and not U.remount then U.alertSearch.poll() end
 if U.chatLog then
  local now=V.call("clock")
  if V.finite(now) and (not U.chatLog.nextUpdate or now<U.chatLog.nextUpdate-1 or now>=U.chatLog.nextUpdate)then
   U.chatLog.nextUpdate=now+0.5;U.chatLog.update(now)
  end
 end
 if U.geStatus then
  local Prices=require("src/prices")
  local message=Prices.permissionStatus()..". "..tostring(V.status.geTest or "Click Test GE connection to verify prices without a loot drop.")
  if message~=U.lastGEStatus then U.geStatus.content=message;U.lastGEStatus=message end
 end
 if U.context and U.view then
  local parent=U.context.parent
  if parent.width~=U.width or parent.height~=U.height then
   local window=require("src/ui/settings_host").state
   window=window and window.editorWindow
   if U.resizeWidth~=parent.width or U.resizeHeight~=parent.height then
    U.resizeWidth=parent.width;U.resizeHeight=parent.height;U.resizeQuiet=0
   end
   U.resizeQuiet=(U.resizeQuiet or 0)+1
   if (window and window.resize and window.resize.dragState) or U.resizeQuiet<4 then return end
   -- Native tab groups do not consistently expose SetSize. Rebuild only the
   -- editor contents, preserving raw input (including unfinished numbers).
   local pending={}
   for i,input in ipairs(U.inputs or {})do pending[i]=input:GetText() end
   local scroll=U.view.scrollY
   local context=U.context
   if U.layout and U.layout.capture then U.layout.capture() end
   U.mount(context.parent,context.d,context.test,context.reset,context.testSound,context.options)
   for i,value in ipairs(pending)do if U.inputs[i] then U.inputs[i]:SetText(value,false) end end
   if V.finite(scroll) and U.view.SetScrollPosition then U.view:SetScrollPosition(scroll)end

  end
 end
 if U.remount and U.context then
  local c=U.context;local pending=U.rebuildInputs;U.rebuildInputs=nil
  U.mount(c.parent,c.d,c.test,c.reset,c.testSound,c.options)
  for i,value in ipairs(pending or {})do if U.inputs[i]then U.inputs[i]:SetText(value,false)end end
 end
end
function U.mount(parent,d,test,reset,testSound,options)
 U.destroy()
 options=options or {}
 local globalSettings=d
 U.context={parent=parent,d=d,test=test,reset=reset,testSound=testSound,options=options}
 if options.section=="presets" and not options.compactPresets then
  local editing=PresetsUI.editorOptions(function()U.remount=true end)
  if editing then options=editing;d=editing.data or d
  elseif PresetsUI.session then
   local displayOptions={};for key,value in pairs(options)do displayOptions[key]=value end
   displayOptions.back=nil;options=displayOptions
  end
 end
 U.width=parent.width; U.height=parent.height
 local isDraft=options.draft~=nil
 local footerHeight=isDraft and 66 or 0
 U.view=prettyui.SimpleView.new(parent,{width=parent.width,height=math.max(100,parent.height-footerHeight),scrollable=true})
 if isDraft then U.footer=prettyui.SimpleView.new(parent,{x=0,y=-66,yAnchor=1,width=parent.width,height=66,scrollable=false})end
 U.columns={}
 U.inputs={}
 U.children={}
 local function childView(parent,opts)
  local child=prettyui.SimpleView.new(parent,opts)
  U.children[#U.children+1]=child
  return child
 end
 local view=U.view
 local validators={}
 local function help(page,value)if globalSettings.showHelp~=false then return page:AddText(value)end end
 local localValidationStatus
 local function save() if not isDraft and not options.localOnly then S.save(d) end end
 local function resetConfig() if not isDraft and not options.localOnly then reset() end end
 local function check(page,label,t,k,change)
  page:AddCheckboxButton({{text=label,value=k,selected=t[k]}},{onChange=function(_,_,_,selected)
   V.safe(function() t[k]=selected; save(); if change then change() end end)
  end})
 end
 local function number(page,label,t,k,min,max,integer)
  page:AddText({text=label,height=isDraft and 20 or 22,marginTop=0,marginBottom=2})
  local field
  field=page:AddTextField({text=tostring(t[k]),height=30,marginTop=0,marginBottom=0,onSubmit=function(field,text)
   V.safe(function()
    local n=tonumber(text)
    if V.finite(n) and n>=(min or 0) and (not max or n<=max) and (not integer or n%1==0) then t[k]=n; save(); resetConfig()
    else field:SetText(tostring(t[k]),false) end
   end)
  end})
  U.inputs[#U.inputs+1]=field
  if isDraft or options.localOnly then validators[#validators+1]=function()
   local n=tonumber(field:GetText())
   if not V.finite(n) or n<(min or 0) or (max and n>max) or (integer and n%1~=0) then return nil,"Invalid "..label end
   t[k]=n; return true
  end end
 end
 local function choice(page,label,t,k,entries,changed)
  page:AddText({text=label,height=isDraft and 20 or 22,marginTop=0,marginBottom=2})
  -- Integer IDs satisfy the native API; persistent settings retain string values.
  local native,values,selected={},{},1
  for i,entry in ipairs(entries) do
   native[i]={id=i,label=entry.label}; native[i].order=i; values[i]=entry.id
   if entry.id==t[k] then selected=i end
  end
  page:AddComboBox({height=30,marginTop=0,marginBottom=0,entries=native,selectedID=selected,onChange=function(_,id)
   V.safe(function() if values[id]~=nil then t[k]=values[id]; save(); resetConfig(); if changed then changed() end end end)
  end})
 end
 local function text(page,label,t,k)
  page:AddText({text=label,height=isDraft and 20 or 22,marginTop=0,marginBottom=2})
  local field=page:AddTextField({text=tostring(t[k]),height=30,marginTop=0,marginBottom=0,maxLength=k=="name" and 80 or 512,onSubmit=function(_,value)
   V.safe(function() t[k]=value; save(); resetConfig() end)
  end})
  U.inputs[#U.inputs+1]=field
  if isDraft or options.localOnly then validators[#validators+1]=function() t[k]=field:GetText(); return true end end
  return field
 end
 local function unframedRow(host,height)
  local spacer=host:AddText({text="",height=height,width=host.content.width,marginTop=0,marginBottom=0,rowBackground=false})
  -- Text reserves flow space but cannot own UI children. A native Layer is
  -- a ComponentCollection and is the actual parent for the unframed views.
  local layer=ui.Layer.new(host.content)
  layer:SetPos(spacer.x or 0,spacer.y or 0)
  layer:SetSize(host.content.width,height)
  return layer
 end
 local function volumeControl(page,label,t,key)
  local slider,input
  local caption=page:AddText({text=label..": "..t[key].."%",width=210,height=28})
  local function setVolume(value)
   if not V.finite(value) then return end
   t[key]=math.floor(math.max(0,math.min(100,value))+0.5)
   caption.content=label..": "..t[key].."%"
   if input then input:SetText(tostring(t[key]),false) end
   save()
  end
  input=page:AddTextField({text=tostring(t[key]),width=76,height=28,inline=true,
   tooltip="0–100. Press Enter to apply.",onSubmit=function(field,value)
    V.safe(function()
     local n=tonumber(value)
     if V.finite(n) and n>=0 and n<=100 then
      setVolume(n)
      if slider then slider:SetValue(t[key],false) end
     end
     field:SetText(tostring(t[key]),false)
    end)
   end})
  U.inputs[#U.inputs+1]=input
  if isDraft or options.localOnly then validators[#validators+1]=function()
   local n=tonumber(input:GetText())
   if not V.finite(n) or n<0 or n>100 then return nil,"Volume must be 0–100" end
   setVolume(n); return true
  end end

  -- Reserve enough height for the native slider's labels; avoid a visible panel frame.
  local row=unframedRow(page,76)
  local panel=childView(row,{width=page.content.width,height=76,scrollable=false})
  slider=V.safe(function()
   local style=id.StyleSheet.SLIDER_DEFAULT
   if style==nil then return nil end
   local c=ui.Slider.new(panel.content)
   c:SetPos(8,0); c:SetSize(math.max(100,panel.content.width-16),68)
   c.stylesheetID=style
   if c:Setup(0,100,math.floor(t[key]+0.5),1,10)==false then c:Destroy(); return nil end
   Wheel.bind(c,page)
   c:Subscribe(ui.Hook.ONSELECTIONCHANGED,function(component)
    V.safe(function() setVolume(component.value) end)
   end)
   return c
  end)
  if not slider then
   slider=panel:AddSlider({min=0,max=100,value=t[key],step=10,onChange=function(control,n)
    V.safe(function() setVolume(V.finite(n) and n or control) end)
   end})
  end
 end

 local function columns(host,ratios,height)
  local panels={};local x=0;local gap=10
  local width=host.content.width
  local spacer=host:AddText({text="",height=height,width=width,marginTop=0,marginBottom=0,rowBackground=false})
  for index,ratio in ipairs(ratios)do
   local w=math.max(60,(width-gap*(#ratios-1))*ratio)
   local column={width=w,height=height,content={width=w},cursor=0,x=x}
   local function position(opts,defaultHeight)
    local out={};for k,v in pairs(opts or {})do out[k]=v end
    out.absolute=true;out.x=(spacer.x or 0)+column.x;out.y=(spacer.y or 0)+column.cursor+(out.marginTop or 0)
    out.width=out.width and (out.width<0 and math.max(60,w+out.width) or out.width) or w
    out.widthAnchor=nil;out.xAnchor=nil;out.yAnchor=nil
    out.height=out.height or defaultHeight
    column.cursor=column.cursor+(out.marginTop or 0)+out.height+(out.marginBottom or 0)
    out.marginTop=0;out.marginBottom=0
    return out
   end
   function column:AddText(value)
    return host:AddText(position(type(value)=="table" and value or {text=value},24))
   end
   function column:AddTextField(opts)local geometry=position(opts,30);column.fieldGeometry=geometry;return host:AddTextField(geometry)end
   function column:AddComboBox(opts)return host:AddComboBox(position(opts,30))end
   function column:AddCheckboxButton(entries,opts)return host:AddCheckboxButton(entries,position(opts,32))end
   panels[index]=column;x=x+w+gap
  end
  U.columns[#U.columns+1]={host=host,panels=panels,ratios=ratios,height=height,gap=gap}
  return table.unpack(panels)
 end
 local alertSections={}
 if options.back and not isDraft then view:AddSimpleButton(options.backLabel or (isDraft and "Cancel" or "Back to alerts"),function()
  V.safe(function()
   if options.localOnly then
    for _,validate in ipairs(validators)do
     local ok,err=validate()
     if not ok then if localValidationStatus then localValidationStatus.content=tostring(err)end;return end
    end
   end
   options.back()
  end)
 end) end
 if isDraft then
  local c=options.draft; local key=c.type
  local editorStatus
  local function captureFields()
   for _,validate in ipairs(validators)do
    local ok,err=validate()
    if not ok then if editorStatus then editorStatus.content=err end;return false end
   end
   return true
  end
  local function refreshEditor() if captureFields() then U.remount=true end end
  local function expandSection(host,label,stateKey,defaultOpen)
   if U[stateKey]==nil then U[stateKey]=defaultOpen==true end
   host:AddSimpleButton((U[stateKey] and "Hide: " or "Show: ")..label,function()
    V.safe(function()
     if captureFields() then U[stateKey]=not U[stateKey];U.remount=true end
    end)
   end,{tooltip=label,height=28,marginTop=4,marginBottom=4})
   return U[stateKey]
  end
  if U.catalogDraft~=c then
   U.catalogDraft=c;U.catalogCategory=Catalog.category(c);U.catalogQuery="";U.catalogPage=nil;U.activeAlertTab=1;U.typeOpen=options.isNew==true;U.recentOpen=false
  end
  if U.catalogCategory=="all" or not U.catalogCategory then U.catalogCategory=Catalog.category(c) end
  text(view,"Alert name (optional)",c,"name")
  local selectedEntry=Catalog.byID[Catalog.current(c)]
  view:AddSimpleButton("Select alert: "..(selectedEntry and selectedEntry.label or c.label)..(U.typeOpen and " [-]" or " [+]"),function()
   if captureFields()then U.typeOpen=not U.typeOpen;U.remount=true end
  end,{tooltip="Show or hide the alert type chooser",absolute=true,x=12,y=64,width=math.max(120,view.content.width-24),height=32,marginTop=0,marginBottom=0})
  local matches,values=Catalog.options(U.catalogCategory,U.catalogQuery),{}
  local tabsTop=108
  if U.typeOpen then
  local search,picker,searchNote
  local changing=false
  local lastChoices
  local function rebuildChoices()
   matches=Catalog.options(U.catalogCategory,U.catalogQuery)
   local pages=math.max(1,math.ceil(#matches/Catalog.pageSize))
   local current=Catalog.current(c)
   if not U.catalogPage then
    U.catalogPage=1
    for index,entry in ipairs(matches)do if entry.id==current then U.catalogPage=math.floor((index-1)/Catalog.pageSize)+1;break end end
   end
   U.catalogPage=math.max(1,math.min(pages,U.catalogPage))
   local entries={};values={}
   local legacy=c.type=="buff" and require("src/timers").catalog[c.buffID]
   if U.catalogQuery=="" and not Catalog.byID[current] and legacy then
    entries[1]={id=1,label=legacy.label.." (saved timer)",order=1,selected=true};values[1]=current
   end
   for index=(U.catalogPage-1)*Catalog.pageSize+1,math.min(#matches,U.catalogPage*Catalog.pageSize)do
    local entry=matches[index];local id=#entries+1
    entries[id]={id=id,label=entry.label,order=id,selected=entry.id==current};values[id]=entry.id
   end
   local selectedID=0
   for id,value in pairs(values)do if value==current then selectedID=id end end
   if #entries==0 then entries={{id=0,label="No matching alerts",disabled=true}} end
   local signature={}
   for _,entry in ipairs(entries)do signature[#signature+1]=tostring(entry.id)..":"..entry.label..":"..tostring(entry.selected) end
   signature=table.concat(signature,"|")
   changing=true
   if picker and lastChoices~=signature then picker:SetEntries(entries) end
   lastChoices=signature
   changing=false
   if searchNote then searchNote.content=string.format("%d results · page %d / %d%s",#matches,U.catalogPage,pages,U.catalogQuery~="" and " · all categories" or "") end
   return entries,selectedID
  end
  local function applyFilter(query,chooseFirst)
   U.searchPending=nil
   if chooseFirst and search then search:SetText(query or "",false) end
   U.catalogQuery=query or "";U.catalogPage=1
   rebuildChoices()
   if chooseFirst and matches[1] and captureFields() then
    Catalog.apply(c,matches[1].id);U.catalogCategory=Catalog.category(c);U.activeAlertTab=1;U.remount=true
   end
  end
  local initialEntries=rebuildChoices()
  local resultHeight=math.max(30,math.min(112,#initialEntries*24+6))
  local pageCount=math.ceil(#matches/Catalog.pageSize)
  local chooserHeight=158+resultHeight+(pageCount>1 and 28 or 0)
  local chooser=view:AddPanel({absolute=true,x=0,y=104,width=view.content.width,height=chooserHeight,scrollable=false,marginTop=0,marginBottom=0})
  local categoryHost,searchHost=columns(chooser,{0.5,0.5},76)
  choice(categoryHost,"Category",U,"catalogCategory",Catalog.categories,function()
   if not captureFields() then return end
   applyFilter("",true)
  end)
  searchHost:AddText({text="Search alerts",height=20,marginTop=0,marginBottom=2})
  search=searchHost:AddTextField({text=U.catalogQuery or "",height=30,marginTop=0,marginBottom=0,width=-40,widthAnchor=1,maxLength=120,
   placeholder="Search all alerts · health, eal, hp, ovl…",
   onChange=function(_,_,value)if type(value)=="string" then U.searchPending=value end end,
   onSubmit=function(_,value)search:SetText(value,false);applyFilter(value,true);if U.remount then U.typeOpen=false end end})
  local searchGeometry=searchHost.fieldGeometry
  chooser:AddSimpleButton("X",function()search:SetText("",false);applyFilter("")end,{absolute=true,x=searchGeometry.x+searchGeometry.width+6,y=searchGeometry.y,width=28,height=searchGeometry.height,tooltip="Clear search"})

  chooser:AddText({text="Alert type · select a result",absolute=true,x=0,y=80,height=18})
  local entries,selectedID=rebuildChoices()
  picker=chooser:AddList({x=0,y=102,absolute=true,entries=entries,maxSelected=1,selectedID=selectedID,height=resultHeight,onChange=function(_,id,selected)
   if changing or selected==false then return end
   V.safe(function()
    if values[id] and captureFields() then
     Catalog.apply(c,values[id]);U.catalogCategory=Catalog.category(c);U.activeAlertTab=1;U.typeOpen=false;U.remount=true
    end
   end)
  end})
  searchNote=chooser:AddText({text="",x=0,y=106+resultHeight,absolute=true,height=22})
  rebuildChoices()
  local function changePage(delta)
   U.catalogPage=math.max(1,(U.catalogPage or 1)+delta);rebuildChoices()
  end
  if pageCount>1 then
   chooser:AddSimpleButton("Previous alerts",function()changePage(-1)end,{absolute=true,x=0,y=130+resultHeight,height=24})
   chooser:AddSimpleButton("Next alerts",function()changePage(1)end,{absolute=true,x=136,y=130+resultHeight,height=24})
  end
  tabsTop=104+chooserHeight+10
  U.searchPending=nil
  U.alertSearch={poll=function()
   local value=U.searchPending or search:GetText();U.searchPending=nil
   if value~=U.catalogQuery then applyFilter(value) end
  end}
  end
  local sectionHeight=math.max(240,parent.height-footerHeight-tabsTop-6)
  local page=view
   local sections=page:AddTabs({{text="Trigger"},{text="Sound"},{text="Display"}}, {x=0,y=tabsTop,absolute=true,height=sectionHeight,scrollable=true,_onScrollWheel=Wheel.forward(view),activeIndex=math.min(3,U.activeAlertTab or 1),onChange=function(_,index)
    if index==(U.activeAlertTab or 1) then return end
    U.activeAlertTab=index
    -- Recreate the editor on tab changes to tear down native dropdown overlays
    -- which PrettyUI otherwise leaves visible above the newly selected page.
    local pending={};for i,input in ipairs(U.inputs)do pending[i]=input:GetText()end
    captureFields();U.rebuildInputs=pending;U.remount=true
   end})
   alertSections[#alertSections+1]=sections
   local trigger,sound,display=sections:GetPage(1),sections:GetPage(2),sections:GetPage(3)
   local chatExtras

   if key=="chat" then
    local phrase=text(trigger,"Trigger word or phrase",c,"chatText")
    local filterHelp
    local channelHost,matchHost=columns(trigger,{0.55,0.45},76)
    choice(channelHost,"Read messages from",c,"chatChannel",Chat.channels,function()
     if filterHelp then filterHelp.content=Chat.filterHelp[c.chatChannel] end
    end)
    choice(matchHost,"Match",c,"chatMatch",{{id="contains",label="Contains phrase (plain text)"},{id="exact",label="Exact message"}})
    check(trigger,"Case-sensitive matching",c,"chatCaseSensitive")
    chatExtras=function()
    if expandSection(trigger,"Recent chat messages · last minute","recentOpen",false) then
    local recent=trigger
    local note=recent:AddText({text="",height=24})
    local log={page=1,signature=nil,updating=false}
    U.chatLog=log
    local list=recent:AddList({entries={{id=0,label="No recent messages",disabled=true}},maxSelected=1,selectedID=0,height=150,
     onChange=function(_,id,selected)
      if log.updating or selected==false then return end
      V.safe(function()
       for _,entry in ipairs(Chat.recent(V.call("clock"),c.chatChannel))do
        if entry.id==id then
         if entry.truncated and c.chatMatch=="exact" then note.content="Choose Contains phrase for this long message.";return end
         c.chatText=entry.text;phrase:SetText(entry.text,false);return
        end
       end
       note.content="Message expired; choose a newer message."
      end)
     end})
    log.update=function(now)
     local messages=Chat.recent(now,c.chatChannel)
     local pages=math.max(1,math.ceil(#messages/8));log.page=math.max(1,math.min(pages,log.page))
     local entries,signature={},{}
     for index=(log.page-1)*8+1,math.min(#messages,log.page*8)do
      local entry=messages[index]
      entries[#entries+1]={id=entry.id,label=entry.text..(entry.truncated and "…" or ""),order=#entries+1}
      signature[#signature+1]=entry.id
     end
     local key=table.concat(signature,",")
     if key~=log.signature then
      if #entries==0 then entries={{id=0,label="No recent messages",disabled=true}} end
      log.updating=true;list:SetEntries(entries);log.updating=false;log.signature=key
     end
     local caption=string.format("%d messages · page %d / %d · click a message to use it",#messages,log.page,pages)
     if note.content~=caption then note.content=caption end
    end
    recent:AddSimpleButton("Newer messages",function()log.page=math.max(1,log.page-1);log.update(V.call("clock"))end)
    recent:AddSimpleButton("Older messages",function()log.page=log.page+1;log.update(V.call("clock"))end,{inline=true})
    log.update(V.call("clock"))
    end
    U.permissionRows={{name="chatAccess",label="Chat",control=trigger:AddText(V.permissionStatus("chatAccess","Chat"))}}
    trigger:AddSimpleButton("Manage chat permission",function()V.requestPermissions()end)
    U.permissionNote=trigger:AddText({text=V.status.permissions or "Open Plugin Hub > AFK ALERTS > padlock to manage optional permissions.",height=72,maxLines=4})
    help(trigger,"Required: allow Chat access in Plugin Hub permissions. Only new messages trigger alerts; old chat history is not scanned. Plugin messages and outgoing private messages are ignored.")

    filterHelp=help(trigger,{text=Chat.filterHelp[c.chatChannel],height=100,maxLines=5})
    help(trigger,"These are recommended game chat settings. The API documentation does not specify whether hiding a chat tab suppresses its events. Test the exact message with your current filters.")
    end
   elseif key=="skill" or key=="idle" then
    choice(trigger,"Skill",c,"skill",S.skills)
    if key=="idle" then
     help(trigger,"Arms after XP is gained, then measures time without more XP. Choose a delay longer than a normal action.")
    end
   elseif key=="inventory" then
    help(trigger,"Uses occupied backpack slots. Above 27 triggers at all 28 slots used. Item stacks use one slot. This does not detect containers or resource pouches becoming full.")
   elseif key=="drop" then
    help(trigger,"Tracks new ground items owned by you. Bank withdrawals and trades do not count.")
    if c.lootSource~="owned_ground" then
     trigger:AddText("This saved alert uses an unavailable loot source.")
     trigger:AddSimpleButton("Use owned ground items",function()c.lootSource="owned_ground";refreshEditor()end)
    end
    choice(trigger,"Measure matching loot by",c,"dropMetric",{{id="count",label="Item count"},{id="ge",label="GE guide value (coins)"},{id="high_alch",label="High Alch value (coins)"}},refreshEditor)
    text(trigger,"Exact item name · blank means all items",c,"itemNameFilter")
    help(trigger,"Name matching ignores case and outer spaces. Only matching items count toward the threshold. Value = unit price × quantity, summed for the drop batch.")
    if c.dropMetric=="ge" then
    trigger:AddSimpleButton("Request HTTP access",function()
     V.safe(function() require("src/prices").allowRequests() end)
    end)
    trigger:AddSimpleButton("Test GE connection",function()
     V.safe(function() require("src/prices").testConnection() end)
    end)
    U.geStatus=trigger:AddText({text=require("src/prices").permissionStatus()..". Click Test GE connection to check prices without a loot drop.",height=100,maxLines=5})
    help(trigger,"GE means Grand Exchange guide price, multiplied by item quantity. It needs HTTP permission. A rounded fallback price is marked ≈. High Alch is calculated separately from base value (before rune costs). Unknown prices never count as zero.")
    elseif c.dropMetric=="high_alch" then help(trigger,"High Alch uses item base values before rune costs; it does not need HTTP permission.") end
   elseif key=="overload" or key=="familiar" or key=="antifire" or key=="aggression" or key=="buff" then
    local Durations=require("src/buff_durations")
    local Timers=require("src/timers")
    help(trigger,{text=Durations.describe(key,c.buffID),height=52,maxLines=3})
    if key=="buff" and Timers.isTarget(c.buffID) then
     help(trigger,"Triggers only when the selected debuff is missing on your current NPC target for 2 seconds. No target or unavailable data produces no alert. Reapplied debuffs reset the alert. Remaining time is not available from these flags.")
    else
     help(trigger,"Uses the live timer. Absolute thresholds are seconds remaining. Percentages use a base or observed duration.")
    end
   end
   local presenceOnly=key=="buff" and require("src/timers").isTarget(c.buffID)
   if key~="chat" and not presenceOnly then
   local timer=key=="buff" or require("src/timers").names[key]~=nil
   local absolute=timer and "Seconds remaining" or key=="idle" and "Seconds without XP" or key=="inventory" and "Occupied slots" or key=="drop" and (c.dropMetric=="count" and "Item count" or "Coins") or key=="skill" and "Skill level" or "Points"
   local modeHost,valueHost,directionHost=columns(trigger,{0.40,0.25,0.35},76)
   choice(modeHost,"Threshold type",c,"mode",{{id="percent",label="Percent of maximum"},{id="absolute",label=absolute}},refreshEditor)
   number(valueHost,"Threshold",c,"threshold")
   choice(directionHost,"Direction",c,"direction",{{id="below",label="Below threshold"},{id="above",label="Above threshold"}})
   end
   if c.mode=="percent" and (key=="idle" or key=="drop")then number(trigger,"Reference maximum for percent",c,"reference",1)end
   check(trigger,"Repeat until reset",c,"repeat")
   if key~="chat" and not presenceOnly then
    local cooldownHost,gapHost,unitHost=columns(trigger,{0.30,0.30,0.40},76)
    number(cooldownHost,"Cooldown (seconds)",c,"cooldown",0.1)
    number(gapHost,"Reset gap (hysteresis)",c,"hysteresis")
    choice(unitHost,"Reset gap unit",c,"hysteresisMode",{{id="percent",label="Percentage points"},{id="absolute",label="Absolute value"}})
    help(trigger,"A reset gap prevents repeated alerts near a threshold. Use 0 for no gap.")
   else
    number(trigger,"Cooldown (seconds)",c,"cooldown",0.1)
    if key=="chat" then help(trigger,"Cooldown limits new matching messages. Repeat replays the alert during its display duration. Each added chat alert has its own trigger and cooldown.")end
   end
   if chatExtras then chatExtras()end
   local soundHost,muteHost=columns(sound,{0.70,0.30},76)
   choice(soundHost,"Alert sound",c,"sound",A.catalog(c.sound))
   check(muteHost,"Mute this alert",c,"muted")
   volumeControl(sound,"Alert volume",c,"volume")
   help(sound,"Use Sound only to preview. Add custom OGG files through Settings > Sounds; MP3 import is currently Linux-only.")
   local barHost,popupHost=columns(display,{0.5,0.5},48)
   check(barHost,"Progress bar",c.visuals,"bar")
   check(popupHost,"Text popup",c.visuals,"popup")
   local flashHost,circleHost=columns(display,{0.5,0.5},48)
   check(flashHost,"Screen flash",c.visuals,"flash")
   check(circleHost,"Monitor row highlight",c.visuals,"circle")
   number(display,"Timed effects duration (seconds)",c,"duration",0.1)
   help(display,"Text popups stay at the top centre until you click anywhere in RuneScape. The duration applies to flash/circles and temporary loot/chat status, not the text popup. Progress bars and circles use the alert monitor; keep it open for these displays. Tests are previews and never enable an alert.")

  local status=U.footer:AddText({text="",absolute=true,x=0,y=0,width=parent.width,height=22,maxLines=1});editorStatus=status
  local function flush()
   if U.remount then status.content="Updating alert settings...";return false end
   if #matches==0 then status.content="No matching alerts. Clear the search or choose another category.";return false end
   local found=false;for _,entry in ipairs(matches)do if entry.id==Catalog.current(c)then found=true end end
   if not found and Catalog.byID[Catalog.current(c)] then status.content="Select an alert from the search results first.";return false end
   if key=="drop" and c.lootSource~="owned_ground" then status.content="Select the supported owned-ground source before saving.";return false end
   if key=="buff" then
    local Timers=require("src/timers")
    if not Timers.supports(c.buffID) then status.content="Choose an effect before saving or testing.";return false end
    Timers.configure(c)
   end
   for _,validate in ipairs(validators) do local ok,err=validate(); if not ok then status.content=err; return false end end
   return true
  end
  U.footer:AddSimpleButton("Test alert",function() V.safe(function() if flush() then test("__preview",c) end end) end,{absolute=true,x=0,y=28,width=100,height=28})
  U.footer:AddSimpleButton("Sound only",function() V.safe(function() if flush() and testSound then testSound("__preview",c) end end) end,{absolute=true,x=108,y=28,width=96,height=28})
  if options.back then U.footer:AddSimpleButton("Cancel",options.back,{absolute=true,x=-198,xAnchor=1,y=28,width=82,height=28})end
  U.footer:AddSimpleButton(options.isNew and "ADD" or "SAVE",function() V.safe(function()
   if not flush() then return end
   local ok,err=options.commit(c)
   if not ok then status.content=err or "Could not save alert" end
  end) end,{absolute=true,x=-108,xAnchor=1,y=28,width=84,height=28})
  U.view:SetContentHeight(tabsTop+sectionHeight+6)
  U.layout={parent=parent,sections=alertSections,draft=c,tabsTop=tabsTop,sectionHeight=sectionHeight,capture=captureFields}
  return
 end
 if options.section=="presets" then
  if options.compactPresets then PresetsUI.mountSharing(view,d,reset,function()U.remount=true end,options.highlights)
  else PresetsUI.mount(view,d,reset,function() U.remount=true end,options.highlights)end
  U.layout={parent=parent}; return
 end
 if options.section=="highlights" then
  local page=view; local c=d.highlighter
   page:AddTitle("Entity highlights")
   check(page,"Enable entity highlights",c,"enabled",resetConfig)
   choice(page,"Entity type",c,"kind",{{id="npc",label="NPCs"},{id="location",label="World objects"},{id="both",label="NPCs and world objects"}})
   text(page,"Names separated by commas",c,"names")
   choice(page,"Name matching",c,"match",{{id="contains",label="Contains name (plain text)"},{id="exact",label="Exact name"}})
   choice(page,"Outline colour",c,"colour",{{id="cyan",label="Cyan"},{id="green",label="Green"},{id="yellow",label="Yellow"},{id="red",label="Red"},{id="purple",label="Purple"}})
   number(page,"Tile outline width (tiles, 0.25–5)",c,"tileSize",0.25,5)
   number(page,"Maximum highlighted entities (1–100)",c,"maxEntities",1,100,true)
   page:AddText("Draws tile outlines under matching NPCs or active world objects. Matching ignores case. Empty names highlight nothing. Outlines respect world geometry; these are tile markers, not model silhouettes. Entity lists refresh once per second.")
   if options.localOnly then localValidationStatus=page:AddText({text="Changes stay in this draft until you click Save preset.",height=44,maxLines=2})end
   page:SetScrollable(true)
  U.layout={parent=parent}; return
 end
 view:AddText("Configure individual alerts through + or Edit. Recording and diagnostics are under Developer.")
 local root=view:AddTabs({{text="General"},{text="Audio"},{text="Sounds"},{text="Developer"}}, {height=math.max(140,parent.height-100),scrollable=true})
 local generalPage=root:GetPage(1)
 check(generalPage,"Show help text",globalSettings,"showHelp")
 generalPage:AddText("Applies to every alert editor. Turn off to hide explanations; controls and status messages stay visible.")
 generalPage:AddTitle("Optional permissions")
 generalPage:AddText("Chat access reads incoming messages for text triggers. HTTP access retrieves GE guide prices from secure.runescape.com. Choose each permission separately in the client; other alerts work without them.")
 U.permissionRows={}
 for _,entry in ipairs({{name="chatAccess",label="Chat"},{name="httpAccess",label="HTTP"}})do
  entry.control=generalPage:AddText(V.permissionStatus(entry.name,entry.label))
  U.permissionRows[#U.permissionRows+1]=entry
 end
 generalPage:AddSimpleButton("Manage permissions",function()V.requestPermissions()end)
 U.permissionNote=generalPage:AddText({text=V.status.permissions or "Open Plugin Hub > AFK ALERTS > padlock to manage optional permissions.",height=72,maxLines=4})
 generalPage:AddText("If the client says a permission could not be changed, it has not been granted. Close the permission window and try again in Plugin Hub. AFK ALERTS cannot override a client rejection.")
 local audioPage=root:GetPage(2)
 check(audioPage,"Mute all alert sounds",d,"masterMuted")
 volumeControl(audioPage,"Master volume",d,"masterVolume")
 choice(audioPage,"Game audio channel",d,"audioBus",{{id="MASTER",label="Master"},{id="SFX",label="Sound effects"}})
 audioPage:AddText("Master volume multiplies each alert's own volume. The game's audio volume also affects playback.")
 audioPage:AddSimpleButton("Test sound",function() V.safe(function() if testSound then testSound("__preview",S.newAlert("health")) end end) end)
 local soundsPage=root:GetPage(3)
 soundsPage:AddTitle("Add your own sounds")
 soundsPage:AddText("Custom audio files must be .ogg (Ogg Vorbis). Custom files currently need an editable local plugin installation.")
 soundsPage:AddText("1. Open your plugin folder. Select and copy the path below:")
 local soundFolder=A.soundFolder()
 soundsPage:AddTextField({text=soundFolder and soundFolder:gsub("/resources/sounds$", "") or "AFK ALERTS folder containing plugin.json",height=34})
 if not soundFolder then
  soundsPage:AddText("The client did not provide an absolute path. Find the AFK ALERTS folder containing plugin.json. For local development, start at the folder configured with plugins_setpath.")
 end
 soundsPage:AddText("Windows: press Win+E to open File Explorer, then Ctrl+L. Paste the path and press Enter.")
 soundsPage:AddText("macOS: open Finder, press Command+Shift+G, paste the path and press Return.")
 soundsPage:AddText("Linux: open your file manager, press Ctrl+L, paste the path and press Enter.")
 soundsPage:AddText("2. Use an .ogg file. Copy it into resources/sounds in the plugin folder. For MP3 files, the external importer currently works only on Linux and converts them to OGG; Windows MP3 import still needs testing.")
 soundsPage:AddText("MP3 is not played directly by the game. The public ZIP includes built-in OGG sounds, without a converter. The optional Linux development helper is separate; Windows MP3 import is unverified. See SOUND_GUIDE.md.")
 soundsPage:AddText("3. Refresh resources in the development client. Enter each console command separately:")
 soundsPage:AddText({text="poff rs3_alerts_plugin\nprf\npon rs3_alerts_plugin",height=78,maxLines=3})
 soundsPage:AddText("4. Return to the alert list, click Edit on your alert > Sound > Alert sound, select the new sound and click Sound only. Select a sound, then click SAVE (or ADD for a new alert).")
 soundsPage:AddText("After adding OGG files or importing on Linux, refresh resources and reopen settings to see the sound in the list. MP3 import is Linux-only for now; Windows testing is still needed.")
 soundsPage:SetScrollable(true)

 local developerPage=root:GetPage(4)
 developerPage:AddTitle("Developer tools")
 developerPage:AddText("Optional tools for troubleshooting and checking effect bindings. Recording stays off until you start it; normal alerts do not need these tools.")
 developerPage:AddTitle("Connection status")
 local fields={{"Recording","recording"},{"Diagnostics","diagnostics"},{"Health","health"},{"Prayer","prayer"},{"Summoning","summoning"},{"Adrenaline","adrenaline"},{"Antifire","antifire"},{"Aggression","aggression"},{"Familiar","familiar"},{"Window","settingsWindow"},{"Monitor","monitor"},{"Loaded data","storageLoaded"},{"Storage","storage"},{"Audio","audio"},{"Chat","chat"},{"Overload","overload"},{"Prices","prices"},{"Activity","activity"},{"Inventory","inventorySpace"},{"Highlights","highlighter"}}
 local rows={}
 local function refresh()
  for i,field in ipairs(fields) do rows[i].content=field[1]..": "..tostring(V.status[field[2]] or "Not read yet") end
 end
 developerPage:AddSimpleButton("Refresh status",function() V.safe(refresh) end)
 developerPage:AddSimpleButton("Read maximum values",function() V.safe(function() require("src/diagnostics").captureLimits(); refresh() end) end)
 developerPage:AddSimpleButton("Read live API snapshot",function() V.safe(function() require("src/diagnostics").capture(); refresh() end) end)
 developerPage:AddTitle("Record effect changes")
 developerPage:AddText("Start once, play normally with your usual effects, then Stop. This records exported numeric timer candidates and vitals/modifiers in the background. It does not enable unverified alerts. Stops after 20 minutes or when its 48 KB limit is reached.")
 local Recorder=require("src/recorder")
 developerPage:AddSimpleButton("Start all-effect recording",function() V.safe(function() Recorder.start(V.call("clock"));refresh() end) end)
 developerPage:AddSimpleButton("Stop recording",function() V.safe(function() Recorder.stop();refresh() end) end)
 local output,exportNote,exportPager
 developerPage:AddSimpleButton("Show recording",function() V.safe(function()
  local data,err=Recorder.export()
  exportPager:show(data,err);refresh()
 end) end)
 developerPage:AddSimpleButton("Previous part",function() V.safe(function() exportPager:move(-1) end) end)
 developerPage:AddSimpleButton("Next part",function() V.safe(function() exportPager:move(1) end) end,{inline=true})
 developerPage:AddText("After Show recording: copy the field with Ctrl+A / Ctrl+C. Paste into a text editor, click Next part and append each part in order. Save all parts together as RS3-buffs.txt and send that file. Your saved recording does not need to be repeated.")
 exportNote=developerPage:AddText({text="No export loaded yet",height=40,maxLines=2})
 output=developerPage:AddTextField({text="Recording export appears here",height=36,maxLength=8000})
 exportPager=require("src/ui/recording_export").new(output,exportNote)
 for i,field in ipairs(fields) do rows[i]=developerPage:AddText({text=field[1]..": "..tostring(V.status[field[2]] or "Not read yet"),height=40,maxLines=2}) end
 developerPage:AddText("Vitals use exported names. Prayer raw readings are divided by ten to match HUD points; summoning uses its raw points; both maxima use ten points per skill level; adrenaline uses ten raw points per percent. Effect timers use the client Logic clock. Elder overload and matching dragonfire end values were observed; other effect variants need HUD checks.")
 U.layout={parent=parent,root=root}
end
return U
