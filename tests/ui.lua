local S=require('src/core/settings')
local P=require('src/core/presets')
local U=require('src/ui/settings_ui')
local combos,buttons,fields,checks,tabs,sliders={},{},{},{},{},{}
local panels,views,collapses,texts={},{},{},{}
local function host(w,h)
 local p={width=w or 1000,height=h or 800}; p.content=p; p.lastText=''
 function p:AddTitle() end
 function p:AddText(value)
  local text=type(value)=='table' and value.text or value
  texts[#texts+1]=text;self.lastText=text; return {content=text,width=type(value)=="table" and value.width or self.width,height=type(value)=="table" and value.height or 24}
 end
 function p:AddTextField(opts)
  local field={text=opts.text}
  function field:GetText() return self.text end
  function field:SetText(value) self.text=value end
  fields[#fields+1]={label=self.lastText,field=field,opts=opts,host=self}; return field
 end
 function p:AddCheckboxButton(entries,opts) checks[#checks+1]={entries=entries,opts=opts} end

 function p:AddList(o)
  o.selectedID=o.selectedID or 0
  self:AddComboBox(o)
  local control={}
  function control:SetEntries(entries)
   assert(#entries<=20,'Native list updates stay bounded')
   o.entries=entries;o.selectedID=0
   for _,entry in ipairs(entries)do if entry.selected then o.selectedID=entry.id end end
  end
  return control
 end
 function p:AddComboBox(opts)
  assert(math.type(opts.selectedID)=='integer')
  for _,entry in ipairs(opts.entries) do assert(math.type(entry.id)=='integer') end
  local control={open=false}
  combos[#combos+1]={label=self.lastText,opts=opts,host=self,control=control}
  assert(#opts.entries<=21,'A native dropdown must never build the whole alert catalogue')
  return control
 end
 function p:AddSimpleButton(label,fn,opts) assert(not opts or not opts.width or opts.width>0,"Buttons need a positive native width");buttons[#buttons+1]={label=label,fn=fn,opts=opts or {},host=self} end
 function p:AddCollapseButton()
  error('CollapseButton is not a form container; use the tab page')
 end
 function p:AddPanel(opts)local child=host(opts.width or self.width-16,opts.height);child.background={alpha=1};child.options=opts;child.parent=self;panels[#panels+1]=child;return child end
 function p:AddTabs(entries,opts)
  local tab={entries=entries,opts=opts};tabs[#tabs+1]=tab
  local pages={}; for i=1,#entries do pages[i]=host(self.width,opts.height-40);pages[i].parent=self end
  tab.pages=pages
  return {GetPage=function(_,i) return pages[i] end}
 end
 function p:SetScrollable() end
 function p:SetSize(w,h) self.width=w; self.height=h end
 function p:SetContentHeight(value)self.contentHeight=value end
 function p:Destroy()
  self.destroyed=true
  for _,combo in ipairs(combos)do local node=combo.host;while node do if node==self then combo.control.open=false;break end;node=node.parent end end
 end
 return p
end
local function layer(parent)
 assert(parent and parent.content==parent,'Layer must attach to a content collection')
 local c={content=nil,width=parent.width,height=parent.height};c.content=c
 function c:SetPos(x,y)self.x=x;self.y=y end
 function c:SetSize(w,h)self.width=w;self.height=h end
 return c
end
id={StyleSheet={SLIDER_DEFAULT=1}}
ui={Layer={new=layer},Hook={ONSELECTIONCHANGED=1},Slider={new=function()
 local c={SetPos=function() end,SetSize=function() end}
 function c:Setup(_,_,value,divisor,increment) self.value=value;self.increment=increment; return true end
 function c:Subscribe(_,fn) self.callback=fn end
 function c:SetValue(value) self.value=value end
 sliders[#sliders+1]=c; return c
end}}
prettyui={SimpleView={new=function(parent,opts)assert(parent and parent.content==parent,"SimpleView parent must be a collection, not Text");local view=host(opts.width or parent.width,opts.height or parent.height);view.options=opts;view.parent=parent;views[#views+1]=view;return view end}}
local db,writes={},0
PersistentDB={SetBool=function(_,k,v) db[k]=v; writes=writes+1; return true end,
 SetString=function(_,k,v) db[k]=v; writes=writes+1; return true end}
local function button(label)
 for i=#buttons,1,-1 do if buttons[i].label==label or buttons[i].opts.tooltip==label then return buttons[i].fn end end
 error('Missing button '..label)
end
local function openTypes()
 if not U.typeOpen then button('Show or hide the alert type chooser')();U.tick()end
end
local function field(label)
 for i=#fields,1,-1 do if fields[i].label==label then return fields[i] end end
 error('Missing field '..label)
end
local d=S.defaults()
U.mount(host(),d,function() end,function() end,function() end,{back=function() end})
assert(#tabs==1 and #tabs[1].entries==4 and tabs[1].entries[1].text=='General' and tabs[1].entries[4].text=='Developer','Everyday settings come first; troubleshooting has its own Developer tab')
for _,label in ipairs({'Refresh status','Read maximum values','Read live API snapshot','Start all-effect recording','Stop recording','Show recording'})do
 local found
 for _,control in ipairs(buttons)do if control.label==label then found=control end end
 assert(found and found.host==tabs[1].pages[4],label..' belongs to Developer')
end
for _,control in ipairs(buttons)do if control.label=='Manage permissions' then assert(control.host==tabs[1].pages[1],'Permission controls stay accessible under General')end end
local permissionVars=require('src/core/vars')
local permissionControls=U.permissionRows
assert(#permissionControls==2,'General shows independent optional permission statuses')
local oldPermissionPlugin,oldPermissionEnums=Plugin,PluginPermissions
PluginPermissions={chatAccess=1,httpAccess=2}
Plugin={HasPermission=function(p)return p==1 end}
U.tick()
assert(permissionControls[1].control.content=='Chat access enabled' and permissionControls[2].control.content=='HTTP access disabled')
button('Manage permissions')()
assert(permissionVars.permissionRequestPending,'Settings queues the request outside the native callback')
permissionVars.permissionRequestPending=nil
Plugin,PluginPermissions=oldPermissionPlugin,oldPermissionEnums
assert(sliders[1].increment==10,'Global editor volume uses ten-point increments too')
for _,check in ipairs(checks) do assert(check.entries[1].text~='Enabled','No type-wide enable controls') end
sliders[1].value=40; sliders[1].callback(sliders[1]); assert(d.masterVolume==40)
fields[1].opts.onSubmit(fields[1].field,'90'); assert(d.masterVolume==90)
U.destroy()
assert(U.permissionRows==nil and U.permissionNote==nil,'Destroyed windows release permission labels')
assert(d.showHelp==true,'Help starts enabled')
local helpCheck
for _,control in ipairs(checks)do if control.entries[1].value=='showHelp' then helpCheck=control end end
assert(helpCheck and helpCheck.entries[1].selected,'General exposes the global help preference')
helpCheck.opts.onChange(nil,nil,nil,false)
local textStart=#texts+1
U.mount(host(),d,function()end,function()end,function()end,{draft=S.newAlert('health'),back=function()end})
assert(field('Cooldown (seconds)') and field('Reset gap (hysteresis)'),'Repeat/reset settings are always available')
for i=textStart,#texts do assert(not texts[i]:find('A reset gap prevents',1,true) and not texts[i]:find('Text popups stay',1,true) and not texts[i]:find('Use Sound only',1,true),'Global help preference hides explanations across all editor tabs')end
U.destroy();d.showHelp=true
local chat=S.newAlert('chat');chat.chatText='Seren spirit'
local Chat=require('src/chat');local Vars=require('src/core/vars')
local oldPlugin,oldPermissions,oldTypes,oldClock=Plugin,PluginPermissions,ChatType,Vars.adapters.clock
PluginPermissions={chatAccess=1};Plugin={HasPermission=function()return true end};ChatType={GENERAL=0}
Vars.adapters.clock=function()return 10 end
Chat.record({chatType=0,chatMessage='You already have full prayer.'},9)
U.mount(host(),d,function()end,function()end,function()end,{draft=chat,isNew=true,back=function()end,changeType=function()end,commit=function()return true end})
assert(U.catalogCategory=='Chat messages','Chat editor opens its own category')
local visibleChat=false
for _,combo in ipairs(combos)do if combo.label=='Alert type · select a result' and #combo.opts.entries==1 and combo.opts.entries[1].label=='Chat message' then visibleChat=true end end
assert(visibleChat and field('Trigger word or phrase'),'Chat message offers a trigger phrase without searching a mixed category')
for _,row in ipairs(U.columns)do for _,panel in ipairs(row.panels)do assert(not panel.background,'Field columns use unframed views')end end
assert(not U.chatLog,'Closed history does not construct a hidden list')
field('Trigger word or phrase').field.text='unsaved phrase'
button('Recent chat messages · last minute')();U.tick()
assert(chat.chatText=='unsaved phrase','Expanding history preserves unsaved text')
assert(field('Cooldown (seconds)'), 'Cooldown is immediately available without an Advanced section')
for _,b in ipairs(buttons)do assert(not b.label:find('Advanced',1,true) and not b.label:find('Chat access & help',1,true) and not b.label:find('Display help',1,true),'Editor has no advanced or per-editor help toggles')end
local recent
for _,combo in ipairs(combos)do
 for _,entry in ipairs(combo.opts.entries)do
  if entry.label=='You already have full prayer.'then recent=combo;recent.opts.onChange(nil,entry.id,true);break end
 end
end
assert(recent,'Chat history is a directly clickable list')
assert(chat.chatText=='You already have full prayer.' and field('Trigger word or phrase').field.text==chat.chatText,'Clicking a recent message updates both the draft and its field without remounting')
local nested=U.children
U.destroy()
for _,child in ipairs(nested)do assert(child.destroyed,'Nested views must be explicitly cleaned up')end
assert(not U.chatLog)
Plugin,PluginPermissions,ChatType,Vars.adapters.clock=oldPlugin,oldPermissions,oldTypes,oldClock
local draft=S.newAlert('health'); local committed,previews=0,0
local previousWrites=writes; local firstCheck=#checks+1; local firstTab=#tabs+1
local options={draft=draft,isNew=true,back=function() end,changeType=function() end,
 commit=function(c) assert(c.threshold==50 and c.name=='First warning'); committed=committed+1; return true end}
U.mount(host(),d,function(id,c) assert(id=='__preview' and c==draft); previews=previews+1 end,function() error('Draft must not reset live alerts') end,function() end,options)
assert(sliders[#sliders].increment==10,'Per-alert editor volume uses ten-point increments')
local thresholdCombo
for _,combo in ipairs(combos)do if combo.label=='Threshold type' then thresholdCombo=combo end end
assert(thresholdCombo and thresholdCombo.opts.absolute and thresholdCombo.host.height>76,'Threshold dropdown uses the full tab page instead of a clipped row viewport')
assert(thresholdCombo.opts.width>0 and thresholdCombo.opts.entries[thresholdCombo.opts.selectedID].label=='Percent of maximum','Threshold selection has a visible label')

local categoryControl
for _,combo in ipairs(combos)do if combo.label=='Category'then categoryControl=combo end end
local searchHost=field('Search alerts').host
assert(math.abs(categoryControl.opts.width-(categoryControl.host.content.width-10)/2)<1,'Category takes half the shared frame width')
assert(searchHost==categoryControl.host and field('Search alerts').opts.x>categoryControl.opts.x,'Category and search share one frame without nested viewports')
local clearButton
for _,b in ipairs(buttons)do if b.opts.tooltip=='Clear search' then clearButton=b end end
local searchGeometry=field('Search alerts').opts
assert(clearButton.opts.x==searchGeometry.x+searchGeometry.width+6 and clearButton.opts.y==searchGeometry.y and clearButton.opts.height==searchGeometry.height,'Search clear button sits beside the shorter field on the same baseline')
assert(clearButton.label=='X','Clear uses a supported ASCII label')
assert(U.footer.options.yAnchor==1 and U.footer.options.y==-66 and not U.footer.options.scrollable,'Action footer stays anchored below the scrolling form')
local saveButton
for _,b in ipairs(buttons)do if b.label=='ADD'then saveButton=b end end
assert(saveButton.host==U.footer and saveButton.opts.xAnchor==1,'Primary action belongs to the fixed footer')
assert(#tabs[firstTab].entries==3 and tabs[firstTab].entries[1].text=='Trigger' and tabs[firstTab].entries[3].text=='Display','Three main tabs; repeat/reset controls are directly in Trigger')
for i=firstCheck,#checks do assert(checks[i].entries[1].text~='Enabled','ADD must not have an enable checkbox') end
field('Threshold').field.text='50'
field('Alert name (optional)').field.text='First warning'
button('ADD')()
assert(committed==1 and draft.threshold==50,'ADD reads fields even without pressing Enter')
assert(#d.entryOrder==0 and writes==previousWrites,'Draft controls do not persist or mutate running entries')
button('Test alert')(); assert(previews==1 and not draft.enabled,'Testing a draft does not add/enable it')
field('Threshold').field.text='bad'; button('ADD')(); assert(committed==1,'Invalid fields block ADD')
U.destroy()
local id,existing=S.add(d,'health'); existing.enabled=true; existing.threshold=10
local edit=S.clone(existing); local saved=false
U.mount(host(),d,function() end,function() end,function() end,{draft=edit,back=function() end,commit=function(c) saved=true; assert(c.threshold==8); return true end})
assert(not U.typeOpen and not U.alertSearch and U.layout.tabsTop==108,'Editing starts with the picker collapsed and the trigger immediately visible')
assert(field('Alert name (optional)').host==U.view,'Name field sits directly on the editor without a surrounding panel')
for i=#buttons,1,-1 do if buttons[i].opts.tooltip=='Show or hide the alert type chooser' then assert(buttons[i].host==U.view and buttons[i].opts.y==64,'Select alert sits below the name without a panel');break end end
local editorView,editorField,footer=U.view,field('Threshold').field,U.footer
local built=#views
editorField.text='8'
local windowHost=require('src/ui/settings_host')
local previousHostState=windowHost.state
windowHost.state={editorWindow={resize={dragState={}}}}
U.context.parent:SetSize(640,620);for i=1,4 do U.tick()end
assert(U.view==editorView,'Never destroy scroll controls while native resize capture is active')
windowHost.state.editorWindow.resize.dragState=nil
U.tick()
windowHost.state=previousHostState
assert(U.view~=editorView and #views>built,'Resize rebuilds contents so native tabs without SetSize get the new height')
assert(field('Threshold').field.text=='8','Resizing retains unsaved numeric input')
assert(U.footer.width==640 and U.footer.height==66 and U.view.height==554,'Footer stays separate from the resized scrolling form')
for _,row in ipairs(U.columns)do
 local available=row.host.content.width-row.gap*(#row.panels-1)
 for index,panel in ipairs(row.panels)do assert(math.abs(panel.width-available*row.ratios[index])<1,'Inline field widths follow the resized parent')end
end
button('Show or hide the alert type chooser')();U.tick()
assert(U.typeOpen)
field('Threshold').field.text='8.'
local beforeHeight=U.layout.sectionHeight
U.context.parent:SetSize(760,900);for i=1,4 do U.tick()end
assert(U.typeOpen and U.layout.sectionHeight>beforeHeight,'Expanded selector survives resize and tabs gain available height')
assert(field('Threshold').field.text=='8.','Resize preserves unfinished raw number input')
local openDropdown
for _,combo in ipairs(combos)do if combo.label=='Threshold type' then openDropdown=combo end end
openDropdown.control.open=true
field('Alert name (optional)').field.text='Unsaved name'
field('Threshold').field.text='8.'
tabs[#tabs].opts.onChange(nil,2);U.tick()
assert(not openDropdown.control.open and tabs[#tabs].opts.activeIndex==2,'Switching to Sound destroys the previous tab dropdown overlay')
assert(field('Threshold').field.text=='8.' and field('Alert name (optional)').field.text=='Unsaved name','Tab switch retains raw unfinished input and names')
tabs[#tabs].opts.onChange(nil,1);U.tick()
assert(tabs[#tabs].opts.activeIndex==1 and field('Threshold').field.text=='8.','Returning to Trigger retains its input')
field('Threshold').field.text='8'; button('SAVE')(); assert(saved and existing.threshold==10,'Editor draft is isolated until the caller commits it')
U.destroy()
local overload=S.newAlert('overload')
local startFields=#fields+1
U.mount(host(),d,function() end,function() end,function() end,{draft=overload,isNew=true,back=function() end,changeType=function() end,commit=function() return true end})
for i=startFields,#fields do assert(fields[i].label~='Buff ID / timer identifier','Overload applies to all variants without a potion ID') end
U.destroy()
for _,kind in ipairs({'buff','familiar','antifire','aggression','overload'})do
 local first=#fields+1
 local draft=S.newAlert(kind);draft.mode='absolute'
 U.mount(host(),d,function()end,function()end,function()end,{draft=draft,isNew=true,back=function()end,changeType=function()end,commit=function()return true end})
 local timerMode
 for _,combo in ipairs(combos)do if combo.label=='Threshold type' then timerMode=combo end end
 assert(timerMode and timerMode.opts.entries[timerMode.opts.selectedID].label=='Seconds remaining','Timer dropdown retains its selected seconds label')
 for i=first,#fields do
  assert(not fields[i].label:lower():find('full duration',1,true) and fields[i].label~='Full timer duration (seconds)','Timer editors must not require manual duration')
 end
 U.destroy()
end
local Timers=require('src/timers')
local Catalog=require('src/core/alert_catalog')
local effectDraft=S.newAlert('buff')
local savedEffect=false
local effectOptions={draft=effectDraft,isNew=true,back=function()end,changeType=function()end,commit=function()savedEffect=true;return true end}
local function chooser(label)
 for i=#combos,1,-1 do if combos[i].label==label then return combos[i]end end
 error('Missing selector '..label)
end
local firstCombo=#combos+1
U.mount(host(),d,function()end,function()end,function()end,effectOptions)
button('ADD')();assert(not savedEffect,'An empty legacy effect cannot be added')
for i=firstCombo,#combos do assert(combos[i].label~='Effect' and combos[i].label~='Effect category','No nested Buff chooser remains')end
local categories=chooser('Category').opts
local targets
for _,entry in ipairs(categories.entries)do
 assert(entry.label~='All alerts','All alerts is removed from the visible category list')
 if entry.label=='Target debuffs' then targets=entry.id end
end
categories.onChange(nil,targets);U.tick()
local effectCombo=chooser('Alert type · select a result')
local targetID
for _,entry in ipairs(effectCombo.opts.entries)do
 assert(entry.order==entry.id,'All alert choices use the searchable ordered selector')
 assert(entry.label~='Buff','No generic Buff option')
 if entry.label=='Vulnerability missing on NPC target' then targetID=entry.id end
end
assert(targetID)
effectCombo.opts.onChange(nil,targetID);U.tick()
assert(effectDraft.buffID=='TARGET_VULNERABILITY' and effectDraft.mode=='percent')
local first=#fields+1
U.mount(host(),d,function()end,function()end,function()end,effectOptions)
for i=first,#fields do assert(fields[i].label~='Threshold' and fields[i].label~='Reset gap (hysteresis)','Target presence has no invented duration controls')end
button('ADD')();assert(savedEffect,'Selected target reminder can be added directly')
openTypes()
local category=chooser('Category');local incenseID
for _,entry in ipairs(category.opts.entries)do if entry.label=='Incense sticks' then incenseID=entry.id end end
category.opts.onChange(nil,incenseID);U.tick()
local result=chooser('Alert type · select a result').opts
assert(#result.entries==18,'Category only shows its own alerts')
assert(effectDraft.buffID=='COMBATV2_INCENSE_BURNER_AVANTOE_END_CLIENT','Category change automatically selects the first item')
assert(result.entries[result.selectedID].label=='Avantoe incense sticks','Selector header and actual configuration match')
local stableField=field('Search alerts').field
local stableView=U.view
stableField.text='kwuarm';U.tick()
assert(U.view==stableView and field('Search alerts').field==stableField,'Typing search must preserve the field, view and focus')
result=chooser('Alert type · select a result').opts
assert(#result.entries==1 and result.entries[1].label=='Kwuarm incense sticks','Visible search bar filters the list')
result.onChange(nil,result.entries[1].id,true);U.tick()
assert(effectDraft.buffID=='COMBATV2_INCENSE_BURNER_KWUARM_END_CLIENT','Clicking the live result selects it')
openTypes()
field('Search alerts').opts.onSubmit(nil,'does not exist');U.tick()
result=chooser('Alert type · select a result').opts
assert(result.entries[1].disabled and result.entries[1].label=='No matching alerts')
savedEffect=false;button('ADD')();assert(not savedEffect,'A zero-result search must not silently save the previous selection')
button('Clear search')();U.tick()
assert(effectDraft.buffID=='COMBATV2_INCENSE_BURNER_KWUARM_END_CLIENT','Clearing search keeps the selected alert')
local activeTabs=tabs[#tabs]
activeTabs.opts.onChange(nil,3)
U.remount=true;U.tick()
assert(tabs[#tabs].opts.activeIndex==3,'Settings refresh preserves the Display tab')
local category=chooser('Category').opts;local large
for _,entry in ipairs(category.entries)do if entry.label=='Other exported effects' then large=entry.id end end
category.onChange(nil,large);U.tick()
local seen={}
local total=#Catalog.options('Other exported effects')
for page=1,math.ceil(total/Catalog.pageSize)do
 local options=chooser('Alert type · select a result').opts
 assert(#options.entries<=Catalog.pageSize,'Large categories are paginated before constructing native controls')
 for _,entry in ipairs(options.entries)do assert(not seen[entry.label]);seen[entry.label]=true end
 options.onChange(nil,options.entries[1].id,true);U.tick();openTypes()
 if page<math.ceil(total/Catalog.pageSize)then button('Next alerts')();U.tick()end
end
local n=0;for _ in pairs(seen)do n=n+1 end;assert(n==total,'Every effect remains reachable without an All alerts list')
button('Previous alerts')();U.tick()
assert(U.catalogPage==math.ceil(total/Catalog.pageSize)-1)
local searchField=field('Search alerts').field
local unchangedView=U.view
for _,query in ipairs({'h','he','eal','hp','health alert'})do
 searchField.text=query;U.tick()
 assert(U.view==unchangedView and field('Search alerts').field==searchField,'Live search never remounts the input')
 local result=chooser('Alert type · select a result').opts
 local health
 for _,entry in ipairs(result.entries)do if entry.label=='Health'then health=entry.id end end
 assert(health,'Health is searchable from Other exported effects: '..query)
end
local result=chooser('Alert type · select a result').opts
local health;for _,entry in ipairs(result.entries)do if entry.label=='Health'then health=entry.id end end
result.onChange(nil,health,true);U.tick()
assert(effectDraft.type=='health' and U.catalogCategory=='Player resources','Clicking a global result updates the type, category and form')
openTypes()
local cat=chooser('Category').opts
for _,entry in ipairs(cat.entries)do if entry.label=='Aspects'then cat.onChange(nil,entry.id);break end end
U.tick()
assert(U.catalogCategory=='Aspects' and U.catalogQuery=='' and field('Search alerts').field.text=='','Changing category clears a previous global search without replaying stale input')
U.destroy()
local Prices=require('src/prices')
local oldAllow,oldTest=Prices.allowRequests,Prices.testConnection
local allowedClicks,testClicks=0,0
Prices.allowRequests=function()allowedClicks=allowedClicks+1 end
Prices.testConnection=function()testClicks=testClicks+1 end
local dropDraft=S.newAlert('drop');dropDraft.dropMetric='ge'
U.mount(host(),d,function()end,function()end,function()end,{draft=dropDraft,isNew=true,back=function()end,changeType=function()end,commit=function()return true end})
button('Request HTTP access')();button('Test GE connection')()
assert(allowedClicks==1 and testClicks==1,'GE buttons use the verified permission and connection-test flows')
U.tick()
local label=U.geStatus
U.destroy();assert(U.geStatus==nil,'Destroyed editors cannot retain a live GE status label')
Prices.allowRequests,Prices.testConnection=oldAllow,oldTest
U.mount(host(),d,function() end,function() end,function() end,{section='presets' ,back=function() end,highlights=function() end})
local PresetsUI=require('src/ui/presets_ui')
button('Save current alerts as preset')();U.tick()
assert(PresetsUI.session and #PresetsUI.session.data.entryOrder==1)
button('Save preset')();U.tick()
assert(d.presets.slot1:match('^RS3ALERTS/2'),'Save stores the edited preset')
button('Back to presets')();U.tick()
button('Edit selected preset')();U.tick()
assert(PresetsUI.session.slot==1,'Saved preset settings open that preset rather than the running list')
local liveThreshold=d.entries[d.entryOrder[1]].threshold
button('Edit')();U.tick()
field('Threshold').field.text='6';button('SAVE')();U.tick()
assert(PresetsUI.session.data.entries[PresetsUI.session.data.entryOrder[1]].threshold==6)
assert(d.entries[d.entryOrder[1]].threshold==liveThreshold,'Preset alert editing remains isolated')
button('Save preset')();U.tick()
assert(P.decode(d.presets.slot1).settings.entries['alert_1'].threshold==6)
local beforeHighlightWrites=writes
local liveHighlights=d.highlighter.enabled
button('Edit preset highlights')();U.tick()
local enable
for i=#checks,1,-1 do if checks[i].entries[1].text=='Enable entity highlights' then enable=checks[i];break end end
assert(enable);enable.opts.onChange(nil,nil,nil,not liveHighlights)
field('Names separated by commas').field.text='fishing spot'
assert(d.highlighter.enabled==liveHighlights and writes==beforeHighlightWrites,'Preset highlight drafts cannot change or persist running settings')
button('Back to preset')();U.tick();button('Save preset')();U.tick()
assert(P.decode(d.presets.slot1).settings.highlighter.enabled~=liveHighlights)
assert(P.decode(d.presets.slot1).settings.highlighter.names=='fishing spot','Returning from preset highlights commits typed fields without needing Enter')


button('Export preset')()
local exported
for i=#fields,1,-1 do if fields[i].opts.maxLength==8000 then exported=fields[i].field.text;break end end
local preset=assert(require('src/core/preset_library').import(exported));assert(#preset.data.entryOrder==1)
button('Back to presets')();U.tick();assert(PresetsUI.session==nil)
d.presets.slot2=P.export(d,'Other setup')
U.mount(host(),d,function()end,function()end,function()end,{section='presets',back=function()end})
local savedList
for i=#combos,1,-1 do
 for _,entry in ipairs(combos[i].opts.entries)do
  if entry.label=='Other setup' then savedList=combos[i];break end
 end
 if savedList then break end
end
assert(savedList,'Saved presets must appear in a selectable list')
savedList.opts.onChange(nil,2);U.tick()
button('Edit selected preset')();U.tick()
assert(PresetsUI.session.slot==2,'Edit opens the selected saved preset')
button('Save preset')();U.tick()
assert(PresetsUI.selectedSlot==2 and d.presets.slot3=='','Saving keeps the selected preset without adding duplicates')
button('Back to presets')();U.tick()
assert(PresetsUI.selectedSlot==2,'Returning to the list preserves the saved selection')
local savedSecond=d.presets.slot2
local runningBefore=P.export(d,'Running')
button('Delete preset')();U.tick()
assert(d.presets.slot2==savedSecond and PresetsUI.deletePending,'Delete first asks for confirmation')
button('Cancel delete')();U.tick();assert(d.presets.slot2==savedSecond)
button('Delete preset')();U.tick();button('Confirm delete')();U.tick()
assert(d.presets.slot2=='' and P.export(d,'Running')==runningBefore,'Confirmed delete preserves active alerts')
button('Undo delete')();U.tick()
assert(d.presets.slot2==savedSecond and PresetsUI.selectedSlot==2)
button('Edit selected preset')();U.tick()
field('Preset name (edit to rename)').field.text='Unsaved name'
button('Back to presets')();U.tick()
assert(PresetsUI.discardPending and d.presets.slot2==savedSecond,'Leaving a dirty draft requires an explicit discard')
button('Keep editing')();U.tick();assert(PresetsUI.session.name=='Unsaved name')
button('Back to presets')();U.tick();button('Discard changes')();U.tick()
assert(not PresetsUI.session and d.presets.slot2==savedSecond)
button('Edit selected preset')();U.tick();button('Save as copy')();U.tick()
assert(PresetsUI.session.slot==3 and PresetsUI.session.name=='Other setup copy' and d.presets.slot2==savedSecond)
button('Back to presets')();U.tick()
local combo=combos[#combos]
local standard
for _,entry in ipairs(combo.opts.entries)do if entry.id>=100 then standard=entry.id;break end end
assert(standard,'Included standards appear in the same selector')
for index,entry in ipairs(combo.opts.entries)do
 assert(entry.order==index,'Preset selector must use explicit ordering to avoid native header/ID mismatch')
 assert(entry.label~='Combat','Combat is no longer included')
end
-- Select every included preset and verify remount, edit and export agree.
local included={}
for _,entry in ipairs(combo.opts.entries)do if entry.id>=100 then included[#included+1]=entry end end
for _,entry in ipairs(included)do
 combos[#combos].opts.onChange(nil,entry.id);U.tick()
 local rendered=combos[#combos].opts
 assert(rendered.selectedID==entry.id,'Remount retains the selected preset ID')
 local header
 for _,option in ipairs(rendered.entries)do if option.id==rendered.selectedID then header=option.label end end
 assert(header==entry.label,'Selected header matches the selected preset name')
 button('Edit selected preset')();U.tick()
 assert(PresetsUI.session.name==header,'Edit opens the preset named by the selector')
 button('Back to presets')();U.tick()
end
combos[#combos].opts.onChange(nil,standard);U.tick()
local libraryBefore=S.clone(d.presets)
button('Delete preset')();U.tick() -- Fake buttons can call disabled callbacks; handler must still protect standards.
assert(not PresetsUI.deletePending and d.presets.slot1==libraryBefore.slot1 and d.presets.slot3==libraryBefore.slot3)
button('Export selected preset')();U.tick()
assert(PresetsUI.session and PresetsUI.session.standard and not PresetsUI.session.slot)
local lastOutput
for i=#fields,1,-1 do if fields[i].opts.maxLength==8000 then lastOutput=fields[i].field.text;break end end
assert(require('src/core/preset_library').import(lastOutput),'Direct export opens a populated, copyable code field')
button('Back to presets')();U.tick()


local function standardCheckbox()
 for i=#checks,1,-1 do if checks[i].entries[1].text=='Show included presets' then return checks[i]end end
end
standardCheckbox().opts.onChange(nil,nil,nil,false);U.tick()
assert(PresetsUI.showStandards==false and db['rs3_alerts.presetLibrary.showStandard']==false)
for _,entry in ipairs(combos[#combos].opts.entries)do assert(entry.id<100,'Hide standards keeps only saved presets in the list')end
standardCheckbox().opts.onChange(nil,nil,nil,true);U.tick()
field('Search presets (press Enter)').opts.onSubmit(nil,'Other setup');U.tick()
for _,entry in ipairs(combos[#combos].opts.entries)do assert(entry.label:find('Other setup',1,true))end
button('Clear search')();U.tick();assert(PresetsUI.filter=='')
button('Edit selected preset')();U.tick()
local draftName=PresetsUI.session.name
button('Save & load')();U.tick()
assert(PresetsUI.lastLoadedName==draftName,'Save & load activates the saved edited preset')
button('Back to presets')();U.tick()

-- Public preset shortcut now uses a compact sharing panel.
U.mount(host(),d,function()end,function()end,function()end,{section='presets',compactPresets=true,back=function()end})
button('Export current alerts')()
local shared
for i=#fields,1,-1 do if fields[i].opts.maxLength==8000 then shared=fields[i].field.text;break end end
assert(require('src/core/preset_library').import(shared),'Compact sharing exports the current monitor setup')
field('Import preset code').field.text=shared
button('Import & load')()
assert(require('src/ui/quick_presets').current(d),'Compact import saves and loads a selectable personal preset')
U.destroy()
local Quick=require('src/ui/quick_presets')
local saved=Quick.current(d).code
PresetsUI.shareExportOnOpen=true
U.mount(host(),d,function()end,function()end,function()end,{section='presets',compactPresets=true,back=function()end})
local ready
for i=#fields,1,-1 do if fields[i].opts.maxLength==8000 then ready=fields[i].field.text;break end end
assert(ready==require('src/core/presets').transfer.encode(saved),'Preset Export prefills the selected stored preset without an extra click')
assert(not PresetsUI.shareExportOnOpen,'Export request is consumed once')
U.destroy()
print('UI passed: lean settings, per-entry drafts, no enable field, ADD/SAVE validation, previews and list presets')
