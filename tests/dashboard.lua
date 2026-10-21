local S=require('src/core/settings')
local V=require('src/core/vars')
local buttons,checks,drawOrder,canvases={},{},{},{}
local function surface(w,h)
 local p={width=w or 348,height=h or 360}; p.content=p
 function p:AddCollapseButton(label,o)
  local child=self:AddPanel({height=400,width=self.width})
  child.collapseLabel=label;child.collapseOptions=o;child.expanded=o.expanded
  function child:SetExpanded(value)self.expanded=value;if o.onToggle then o.onToggle(self,value)end end
  return child
 end
 function p:AddPanel(opts) return surface(self.width-16,opts.height) end
 function p:AddText(opts) return {content=type(opts)=='table' and opts.text or opts} end
 function p:AddSlider(o)
  local control={options=o,value=o.value}
  function control:SetValue(v)self.value=v end
  function control:SetTooltip(v)self.tooltip=v end
  return control
 end
 function p:AddTitle() end

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
 function p:AddComboBox(o)return o end
 function p:AddTextField(o)
  local f={text=o.text};function f:GetText()return self.text end;return f
 end
 function p:AddSpriteButton(name,fn,o)return self:AddSimpleButton('',fn,o)end
 function p:AddSimpleButton(label,fn,opts)
  local shown=label~='' and label or ({['Add an alert']='+',['Settings']='Settings',['Show / hide presets']='Presets',['Load selected preset']='Load',['Export selected preset / import presets']='Export',['Edit']='Edit',['Test']='Test',['Remove this alert from the current list']='×'})[(opts or {}).tooltip]
  local b={label=shown or label,fn=fn,opts=opts or {}}; buttons[#buttons+1]=b
  drawOrder[#drawOrder+1]='button:'..label; return b
 end
 function p:AddCheckboxButton(entries,opts)
  local c={entries=entries,opts=opts,selected=entries[1].selected}
  function c:SetSelected(_,value,notify)assert(not notify);self.selected=value end
  checks[#checks+1]=c;return c
 end
 function p:SetScrollPosition(value)self.scrollY=value end
 function p:SetContentHeight(height) self.contentHeight=height end
 function p:Destroy() self.destroyed=true end
 return p
end
local opened={}
package.loaded['src/ui/settings_ui']={destroy=function() end,tick=function() end,
 mount=function(parent,d,test,reset,testSound,opts) opened[#opened+1]=opts end}
package.loaded['src/ui/settings_host']={closeEditor=function() end,setMode=function(mode) return surface(mode=='list' and 348 or 1000,mode=='list' and 360 or 800) end}
prettyui={SimpleView={new=function(parent,opts)
 local view=surface(opts.width or parent.width,opts.height or parent.height)
 view.layout=opts
 view._onScrollWheel=function(component,delta)
  if opts.scrollable~=false then view.lastWheel=delta;return false end
  if opts._onScrollWheel then return opts._onScrollWheel(component,delta)end
  return true
 end
 return view
end}}
ui={Canvas={new=function()
 drawOrder[#drawOrder+1]='icon'
 local c={lines={},SetPos=function() end,SetSize=function(self,w,h) self.width=w; self.height=h end,Clear=function() end,AddRectangle=function() end}
 function c:AddLine(...) self.lines[#self.lines+1]={...} end
 canvases[#canvases+1]=c; return c
end}}
local db={}
PersistentDB={SetBool=function(_,k,v) db[k]=v; return true end,SetString=function(_,k,v) db[k]=v; return true end}
Vector4={new=function(...)return {...}end}
local time=0; V.adapters.clock=function() return time end
local D=require('src/ui/dashboard')
local d=S.defaults(); local tested,resetIDs={},{ }
local function button(label,tooltip)
 for i=#buttons,1,-1 do if buttons[i].label==label and (not tooltip or buttons[i].opts.tooltip==tooltip) then return buttons[i].fn end end
 error('Missing button '..label..' '..tostring(tooltip))
end
local function add(threshold)
 local monitor=D.view
 button('+')(); D.tick()
 assert(D.view==monitor and not monitor.destroyed,'ADD editor must leave monitor visible')
 local opts=opened[#opened]
 assert(opts.isNew and opts.draft.type=='health')
 opts.draft.threshold=threshold
 assert(opts.commit(opts.draft)); D.tick()
 assert(D.rows[d.entryOrder[#d.entryOrder]],'ADD must immediately populate monitor rows')
 return d.entryOrder[#d.entryOrder]
end
D.mount(surface(),d,function(id) tested[#tested+1]=id end,function(id) resetIDs[#resetIDs+1]=id end,function() end)
assert(#checks==0 and #d.entryOrder==0)
local addButton
for _,b in ipairs(buttons)do if b.label=='+' then addButton=b end end
assert(addButton and addButton.opts.width==32 and addButton.opts.height==28,'Add button has a larger click target')
assert(D.list.layout.y==36 and D.list.height==360-36,'Collapsed presets leave the full list height available')
button('Presets')();D.tick()
assert(D.presetsOpen and D.list.layout.y==104 and D.presetPanel,'Top-right button expands preset controls beneath the toolbar')
assert(D.presetDivider and #D.presetDivider.lines==1,'Open preset dropdown has a bottom separator')
button('Presets')();D.tick()
assert(not D.presetsOpen and D.list.layout.y==36,'Second click collapses the preset controls')
local master=D.volume
assert(master.options.step==10 and master.options.min==0 and master.options.max==100 and master.options.x==104)
assert(master.options.widthAnchor==1 and master.options.width==-174,'Master slider fills remaining width up to Presets, including on resize')
master.options.onChange(master,35)
assert(d.masterVolume==35,'Master volume applies immediately')
for _=1,25 do D.tick()end
assert(db['rs3_alerts.v1.masterVolume']=='35','Toolbar volume persists after dragging stops')
d.masterVolume=72;D.tick()
assert(D.volume.value==72,'Toolbar reflects volume changed in full settings')
master.options.onChange(master,44)
D.destroy()
assert(db['rs3_alerts.v1.masterVolume']=='44','Closing saves a pending volume change')
D.mount(surface(),d,function(id) tested[#tested+1]=id end,function(id)resetIDs[#resetIDs+1]=id end,function()end)

local diskIndex,iconIndex
for i,item in ipairs(drawOrder) do if item=='button:' and not diskIndex then diskIndex=i elseif item=='icon' and not iconIndex then iconIndex=i end end
assert(diskIndex and iconIndex>diskIndex,'Glyph draws above button background')
local first=add(50); local second=add(10)
assert(first~=second and #d.entryOrder==2,'Allow multiple entries of one type')
assert(d.entries[first].threshold==50 and d.entries[second].threshold==10)
assert(d.entries[first].enabled and d.entries[second].enabled,'ADD starts the confirmed entry')
button('Edit')(); D.tick(); local edit=opened[#opened]
edit.draft.threshold=8; assert(d.entries[second].threshold==10,'Editing draft must not change running entry')
edit.back(); D.tick(); assert(d.entries[second].threshold==10,'Cancel discards changes')
button('Edit')(); D.tick(); edit=opened[#opened]; edit.draft.threshold=8
assert(edit.commit(edit.draft)); D.tick()
assert(d.entries[second].threshold==8 and d.entries[first].threshold==50,'SAVE only changes this instance')
assert(resetIDs[#resetIDs]==second,'Only the modified alert resets')
button('Test')(); assert(tested[#tested]==second)
local Visual=require('src/visual'); Visual.samples={[first]={value=75,maximum=100}}
time=1; D.tick(); assert(D.rows[first].caption.content=='75.0%')
local Engine=require('src/core/alerts')
local engine=Engine.new(function(key,c,sample,now)Visual.emit(key,c,sample,now)end)
local function sampleAt(now,value)
 time=now;Visual.samples[first]=value~=nil and {value=value,maximum=100} or nil
 engine:step(first,d.entries[first],Visual.samples[first],now)
 Visual.conditions[first]=engine.states[first] and engine.states[first].active or false
 D.tick()
end
sampleAt(2,25)
assert(D.rows[first].lastColour==0xEE5544FF and D.rows[first].lastFiring,'Trigger makes the bar red and briefly highlights firing text')
assert(D.rows[first].caption.colour[1]==1 and D.rows[first].caption.content:find('ALERT',1,true),'Firing gets gold text and a short label')
Visual.dismissPopups()
sampleAt(7,25)
assert(D.rows[first].lastColour==0xEE5544FF and not D.rows[first].lastFiring,'Bar stays red after the firing pulse ends and the popup is dismissed')
assert(not D.rows[first].caption.content:find('ALERT',1,true),'Firing label is temporary')
sampleAt(7.5,52)
assert(D.rows[first].lastColour==0xEE5544FF,'Bar follows the same reset gap as the real alert engine')
sampleAt(8,55)
assert(D.rows[first].lastColour==0x55BBAAFF,'Safe reset clears red even while a popup remains stored')
Visual.emit(first,d.entries[first],{value=0,maximum=100},8)
sampleAt(8.3,55)
assert(D.rows[first].lastColour==0x55BBAAFF and D.rows[first].lastFiring,'A Test preview can highlight firing without marking safe live data red')
sampleAt(9,nil)
assert(D.rows[first].lastBackground==0x252B33FF,'Unavailable live data clears the red state')
sampleAt(10,0)
assert(D.rows[first].lastFilled==0 and D.rows[first].lastBackground==0xA63832FF,'Zero remaining/health still has a visible red track')
d.entries[first].enabled=false
sampleAt(11,0)
assert(D.rows[first].lastBackground==0x252B33FF,'Paused alerts never retain a red bar')
d.entries[first].enabled=true;sampleAt(12,75)

local oldList,oldRow=D.list,D.rows[second]
D.list:SetScrollPosition(180)
assert(oldRow.volume.options.step==10,"Per-alert volume buttons use ten-percent steps")
local firstVolume=d.entries[first].volume
oldRow.volume.options.onChange(oldRow.volume,22)
assert(d.entries[second].volume==22 and d.entries[first].volume==firstVolume,'Row volume only changes its alert')
for _=1,25 do D.tick()end
assert(D.list==oldList and D.list.scrollY==180,'Changing volume preserves the list and its scroll position')
assert(db[S.listKey]:find('volume=22',1,true),'Per-alert volume is saved')
checks[#checks].opts.onChange(nil,nil,nil,false)
time=time+0.3;D.tick()
assert(D.list==oldList and D.rows[second]==oldRow and D.list.scrollY==180,'Toggling an alert keeps existing rows and scroll position')
assert(not oldRow.checkbox.selected,'Checkbox reflects enabled state without rebuilding')
assert(not d.entries[second].enabled and d.entries[first].enabled,'Pause one instance')
button('', 'Mute alerts')(); D.tick(); assert(d.masterMuted)
assert(D.list.scrollY==180,'Structural toolbar refresh also retains scroll position')
local speaker=canvases[2]; local slash=false
for _,candidate in ipairs(canvases) do for _,line in ipairs(candidate.lines) do if line[6]==0xFF7777FF then speaker=candidate end end end
for _,line in ipairs(speaker.lines) do if line[6]==0xFF7777FF then slash=true end end
assert(slash,'Muted icon must have a slash')
button('', 'Unmute alerts')(); D.tick(); assert(not d.masterMuted)
button('Presets')();D.tick();button('Export')(); D.tick()
assert(opened[#opened].section=='presets' and opened[#opened].compactPresets and opened[#opened].highlights,'Preset shortcut opens the smaller sharing view')
opened[#opened].back(); D.tick()
button('×')(); D.tick()
assert(#d.entryOrder==1 and d.entries[first] and not d.entries[second],'Remove just this instance')
button('+')(); D.tick(); local draft=opened[#opened]
draft.draft.threshold=2; draft.back(); D.tick(); assert(#d.entryOrder==1,'Cancel ADD never creates an entry')
local anyRow
for _,row in pairs(D.rows)do anyRow=row;break end
assert(anyRow,'Monitor still has an alert to test wheel routing')
do
 assert(anyRow.view._onScrollWheel(anyRow.view,2)==false and D.list.lastWheel==2,'Monitor row routes mouse-wheel input to the list')
 assert(D.view._onScrollWheel(D.view,-1)==false and D.list.lastWheel==-1,'Toolbar routes wheel input to the list')
end
-- Rejected storage must retain the draft and the live list, including deletion.
local stored=db[S.listKey]
local write=PersistentDB.SetString
PersistentDB.SetString=function(_,key,value)
 if key==S.listKey then return false end
 return write(nil,key,value)
end
local resetCount=#resetIDs
button('Edit')();D.tick()
local retry=opened[#opened];local threshold=d.entries[first].threshold
retry.draft.threshold=threshold+1
local saved,reason=retry.commit(retry.draft)
assert(not saved and reason:find('draft is retained',1,true))
assert(d.entries[first].threshold==threshold and db[S.listKey]==stored and #resetIDs==resetCount)
assert(D.pending==nil and D.mode=='edit','Failed save keeps the editor open')
retry.back();D.tick()
button('×')();D.tick()
assert(d.entries[first] and #d.entryOrder==1,'Failed deletion keeps the live alert')
checks[#checks].opts.onChange(nil,nil,nil,false)
assert(d.entries[first].enabled,'Failed pause write keeps the running state')
button('+')();D.tick()
local failedAdd=opened[#opened]
assert(not failedAdd.commit(failedAdd.draft) and #d.entryOrder==1,'Failed ADD cannot enable an unsaved alert')
PersistentDB.SetString=write
assert(failedAdd.commit(failedAdd.draft));D.tick()
assert(#d.entryOrder==2,'The retained draft can be saved after storage recovers')
D.destroy(); assert(not D.context and next(D.rows)==nil)
print('Dashboard passed: independent duplicate alerts, ADD/SAVE/cancel, scoped resets, speaker icons and list presets')

local Editor=package.loaded['src/ui/settings_ui']
local Host=package.loaded['src/ui/settings_host']
local attempts=0
Editor.mount=function()attempts=attempts+1;error('Simulated native editor creation failure')end
D.mount(surface(),d,function()end,function()end,function()end)
local stableMonitor=D.view
D.request('settings');D.tick()
assert(attempts==1 and D.view==stableMonitor and V.errors['settings.open'],'Failed editor keeps monitor and reports error')
for i=1,1000 do time=time+0.02;D.tick()end
assert(attempts==1,'Editor creation failure never retries automatically')
D.destroy()
print('Editor opening passed: one failed attempt, preserved monitor and no retry loop')

Visual.sourceStatuses={ge_entry='GE permission required: Edit > Allow GE price requests',other_entry='GE request failed: HTTP 503'}
local drop=S.newAlert('drop');drop.enabled=true
assert(D.summary('ge_entry',drop,0):find('permission required',1,true))
assert(D.summary('other_entry',drop,0):find('503',1,true),'Each alert shows its own price status')
assert(D.summary('fresh_entry',drop,0)=='Waiting for a matching owned ground-item drop','No drop is distinct from a pending price request')
local chat=S.newAlert('chat');chat.enabled=true
Visual.sourceStatuses.chat='Grant optional Chat access in Plugin Hub permissions'
assert(D.summary('chat',chat,0)==Visual.sourceStatuses.chat,'Chat permissions must be visible in the monitor')
local overload=S.newAlert('overload');overload.enabled=true
Visual.sourceStatuses.overload='No overload effect observed'
assert(D.summary('overload',overload,0)==Visual.sourceStatuses.overload,'No active buff is different from an unavailable API')
