-- Real Dashboard + Editor + Host, including native-window resizing and unsent fields.
local S=require('src/core/settings')
local V=require('src/core/vars')
local P=require('src/core/presets')
local fields,buttons,windows,checkboxes,combos={},{},{},{},{}
local function surface(w,h)
 local p={width=w,height=h,lastText=''}; p.content=p
 function p:AddCollapseButton(label,o)
  local child=self:AddPanel({height=400,width=self.width})
  child.collapseLabel=label;child.collapseOptions=o;child.expanded=o.expanded
  function child:SetExpanded(value)self.expanded=value;if o.onToggle then o.onToggle(self,value)end end
  return child
 end
 function p:AddPanel(o) local child=surface(self.width-16,o.height); child.options=o; child.parent=self; return child end
 function p:AddSlider(o)
  local control={options=o,value=o.value}
  function control:SetValue(v)self.value=v end
  function control:SetTooltip(v)self.tooltip=v end
  return control
 end
 function p:AddTitle() end
 function p:AddText(o) local text=type(o)=='table' and o.text or o; self.lastText=text; return {content=text,width=type(o)=="table" and o.width or self.width,height=type(o)=="table" and o.height or 24} end
 function p:AddTextField(o)
  local f={text=o.text,label=self.lastText}
  function f:GetText() return self.text end
  function f:SetText(v) self.text=v end
  fields[#fields+1]=f; return f
 end

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
 function p:AddComboBox(o) combos[#combos+1]={label=self.lastText,options=o};return o end
 function p:AddCheckboxButton(entries,o) self.titleFlow=not o.absolute and o.y==nil; checkboxes[#checkboxes+1]=entries[1] end
 function p:AddSpriteButton(name,fn,o)return self:AddSimpleButton('',fn,o)end
 function p:AddSimpleButton(label,fn,o) buttons[#buttons+1]={label=label~='' and label or ({['Add an alert']='+',['Settings']='Settings',['Show / hide presets']='Presets',['Load selected preset']='Load',['Export selected preset / import presets']='Export',['Edit']='Edit',['Test']='Test',['Remove this alert from the current list']='×'})[(o or {}).tooltip] or label,fn=fn}; return {} end
 function p:AddTabs(entries,o)
  local pages={}; for i=1,#entries do pages[i]=surface(self.width,o.height-40) end
  return {GetPage=function(_,i) return pages[i] end}
 end
 function p:SetScrollPosition(value)self.scrollY=value end
 function p:SetContentHeight(height) self.contentHeight=height end
 function p:SetScrollable() end
 function p:SetSize(w,h) self.width=w; self.height=h end
 function p:Destroy() self.destroyed=true end
 return p
end
prettyui={SimpleView={new=function(parent) local view=surface(parent.width,parent.height); view.parent=parent; return view end},Window={new=function(_,o)
 local w={content=surface(o.width-32,o.height-60),options=o}
 function w:Show() end
 function w:SetSize(width,height) self.content.width=width-32; self.content.height=height-60 end
 function w:Destroy() self.destroyed=true end
 windows[#windows+1]=w; return w
end}}
ui={Hook={ONSELECTIONCHANGED=1},Canvas={new=function(parent)
 local c={rectangles={},parent=parent}
 function c:SetPos(x,y) self.x=x; self.y=y end
 function c:SetSize(w,h) self.width=w; self.height=h end
 function c:Clear() self.rectangles={} end
 function c:AddRectangle(x,y,w,h,colour) self.rectangles[#self.rectangles+1]={width=w} end
 function c:AddLine() end
 return c
end},Slider={new=function() return {SetPos=function() end,SetSize=function() end,Setup=function() return true end,Subscribe=function() end} end}}
ui.Layer={new=function(parent)
 assert(parent and parent.content==parent,'Layer requires a collection')
 local layer=surface(parent.width,parent.height)
 function layer:SetPos(x,y)self.x=x;self.y=y end
 return layer
end}
id={StyleSheet={SLIDER_DEFAULT=1}}
PersistentDB={SetBool=function() return true end,SetString=function() return true end}
V.adapters.gameArea=function() return surface(1488,997) end
local time=0
V.adapters.clock=function() return time end
local D=require('src/ui/dashboard'); local Host=require('src/ui/settings_host'); local Visual=require('src/visual')
local function tick() time=time+0.25; D.tick() end
local d=S.defaults()
local parent=Host.prepare({},D.destroy,'list',d)
D.mount(parent,d,function() end,function() end,function() end)
local monitor=windows[1]
local function click(label) for i=#buttons,1,-1 do if buttons[i].label==label then buttons[i].fn(); return end end; error(label) end
local function field(label) for i=#fields,1,-1 do if fields[i].label==label then return fields[i] end end; error(label) end
click('+'); tick()
assert(not monitor.destroyed and Host.state.window==monitor and Host.state.editorWindow,'Two windows remain available')
field('Alert name (optional)').text='My first warning'
field('Threshold').text='50'
local draftField=field('Alert name (optional)')
local liveEditor=Host.state.editorWindow
assert(liveEditor.options.resizable and monitor.options.resizable,'Both windows allow edge/corner resizing')
liveEditor:SetSize(800,650); for i=1,4 do tick()end
assert(field('Alert name (optional)').text=='My first warning' and Host.state.editorWindow==liveEditor,'Resizing preserves unsent input and the native editor window')
click('ADD'); tick()
local first=d.entryOrder[1]
assert(first and d.entries[first].name=='My first warning' and D.rows[first],'ADD creates visible row without pressing Enter')
assert(not monitor.destroyed and not Host.state.editorWindow,'Confirm closes only the editor')
assert(D.rows[first].progress.y==25 and D.rows[first].progress.width==D.rows[first].progress.parent.width,'Progress fills the row below the title without nested panel insets')
Visual.samples={[first]={value=25,maximum=100}}; tick()
local progress=D.rows[first].progress
assert(#progress.rectangles==2 and progress.rectangles[2].width==math.floor(progress.width/4),'Inline bar reflects live values')
click('+'); tick(); field('Alert name (optional)').text='Critical warning'; field('Threshold').text='10'; click('ADD'); tick()
assert(#d.entryOrder==2 and D.rows[d.entryOrder[2]] and D.rows[first],'Duplicate types both appear')
D.request('add','chat'); tick()
field('Alert name (optional)').text='My Seren spirit'
field('Trigger word or phrase').text='A Seren spirit appears'
click('ADD'); tick()
local chatID=d.entryOrder[3]
assert(chatID and D.rows[chatID] and d.entries[chatID].chatText=='A Seren spirit appears','Chat ADD reads phrase and immediately lists the alert')
click('+');tick()
field('Alert name (optional)').text='My Penance reminder'
local categories
for i=#combos,1,-1 do if combos[i].label=='Category' then categories=combos[i].options;break end end
for _,entry in ipairs(categories.entries)do if entry.label=='Aspects' then categories.onChange(nil,entry.id);break end end
tick()
local picker
for i=#combos,1,-1 do if combos[i].label=='Alert type · select a result' then picker=combos[i].options;break end end
local selected
for _,entry in ipairs(picker.entries)do if entry.label=='Penance (aspect)' then selected=entry.id end end
assert(selected,'Penance is directly selectable without choosing Buff')
picker.onChange(nil,selected)
click('ADD');assert(#d.entryOrder==3,'Cannot save stale fields while changing alert type')
tick()
assert(field('Alert name (optional)').text=='My Penance reminder','Changing type retains typed custom name')
assert(field('Threshold').text=='30','New timer selection defaults to seconds rather than an arbitrary percentage')
field('Threshold').text='15';click('ADD');tick()
local penance=d.entries[d.entryOrder[4]]
assert(penance and penance.type=='buff' and penance.buffID=='COMBATV2_BUFF_PENANCE_END_CLIENT' and penance.threshold==15 and penance.mode=='absolute','Unified selection commits the actual named timer into the running list')
click('Edit'); tick(); local editor=Host.state.editorWindow
local other=S.defaults(); local _,c=S.add(other,'inventory'); c.enabled=true; c.name='Preset backpack'
P.apply(d,assert(P.decode(P.export(other,'Replacement')))); tick()
assert(Host.state.editorWindow==editor and not editor.destroyed,'List refresh leaves editor open')
assert(#d.entryOrder==1 and D.rows[d.entryOrder[1]].config.name=='Preset backpack','Preset replacement refreshes rows')
click('Presets');tick()
local quick
for i=#combos,1,-1 do if combos[i].options.tooltip=='Choose a preset' then quick=combos[i].options;break end end
local bossID
for _,entry in ipairs(quick.entries)do if entry.label=='Bossing' then bossID=entry.id end end
assert(bossID)
quick.onChange(nil,bossID);tick()
assert(#d.entryOrder==1 and Host.state.editorWindow,'Choosing a preset leaves running alerts and the draft intact')
click('Load');tick();tick()
assert(not D.presetsOpen,'Loading closes the preset dropdown')
assert(#d.entryOrder==4 and not Host.state.editorWindow,'Loading from the monitor closes the old alert draft before it can save into a new preset')
D.destroy(); Host.restore(); assert(monitor.destroyed and editor.destroyed)
assert(next(V.errors)==nil,'Native UI workflow must not hide callback errors')
print('ADD integration passed: simultaneous windows, committed name, duplicate rows, inline progress and preset refresh')
