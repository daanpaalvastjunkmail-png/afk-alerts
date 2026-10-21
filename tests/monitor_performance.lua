local S=require('src/core/settings')
local V=require('src/core/vars')
local P=require('src/core/presets')
local fields,buttons,windows,checkboxes={},{},{},{}
local builds,clears,writes=0,0,0
local failRows=false
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
 function p:AddText(o) local text=type(o)=='table' and o.text or o; self.lastText=text
  local values={content=text}
  return setmetatable({}, {__index=values,__newindex=function(_,k,v) writes=writes+1; values[k]=v end}) end
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
 function p:AddComboBox(o) return o end
 function p:AddCheckboxButton(entries,o) if failRows then error('Simulated native row construction failure') end; self.titleFlow=not o.absolute and o.y==nil; checkboxes[#checkboxes+1]=entries[1] end
 function p:AddSpriteButton(name,fn,o)return self:AddSimpleButton('',fn,o)end
 function p:AddSimpleButton(label,fn,o) buttons[#buttons+1]={label=label~='' and label or ({['Add an alert']='+',['Settings']='Settings',['Load selected preset']='Load',['Export selected preset / import presets']='Export',['Edit']='Edit',['Test']='Test',['Remove this alert from the current list']='×'})[(o or {}).tooltip] or label,fn=fn}; return {} end
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
prettyui={SimpleView={new=function(parent) builds=builds+1; local view=surface(parent.width,parent.height); view.parent=parent; return view end},Window={new=function(_,o)
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
 function c:Clear() clears=clears+1; self.rectangles={} end
 function c:AddRectangle(x,y,w,h,colour) self.rectangles[#self.rectangles+1]={width=w} end
 function c:AddLine() end
 return c
end},Slider={new=function() return {SetPos=function() end,SetSize=function() end,Setup=function() return true end,Subscribe=function() end} end}}
id={StyleSheet={SLIDER_DEFAULT=1}}
PersistentDB={SetBool=function() return true end,SetString=function() return true end}
V.adapters.gameArea=function() return surface(1488,997) end
local time=0
V.adapters.clock=function() return time end
local D=require('src/ui/dashboard'); local Host=require('src/ui/settings_host'); local Visual=require('src/visual')
local d=S.defaults(); local first,c=S.add(d,'health'); c.enabled=true
local parent=Host.prepare({},D.destroy,'list',d)
D.mount(parent,d,function()end,function()end,function()end)
Visual.samples={[first]={value=25,maximum=100}}
D.tick()
local initialClears,initialWrites,initialBuilds=clears,writes,builds
for i=1,1000 do time=i/50; D.tick() end
assert(builds==initialBuilds,'Stable monitor must not rebuild on Logic ticks')
assert(clears==initialClears and writes==initialWrites,'Unchanged values must not issue native redraw/text updates')
Visual.samples[first].value=40; time=21; D.tick()
assert(clears==initialClears+1,'Changed value redraws its bar once')
local resizeBuilds=builds
for i=1,25 do
 parent.width=400+i; parent.height=300+i
 time=21+i/50; Host.tick(); D.tick()
 assert(D.rows[first].progress.width==parent.width-4,'Progress tracks available width')
end
assert(builds==resizeBuilds,'Interactive resizing must not allocate new views or rows')
local chosenWidth,chosenHeight=parent.width,parent.height
Host.setMode('list',d)
assert(parent.width==chosenWidth and parent.height==chosenHeight,'List refresh preserves the user-selected window size')
failRows=true
local second=S.add(d,'inventory'); d.entries[second].enabled=true
time=22; D.tick()
local attempts=builds
assert(V.errors.monitor and D.rows[first]==nil,'Native failure switches to bounded text fallback')
assert(d.entries[second] and #d.entryOrder==2,'Native errors never discard added settings')
for i=1,1000 do time=22+i/50; D.tick() end
assert(builds==attempts,'Failed rebuild must not retry and allocate UI every tick')
failRows=false
D.request('list'); time=43; D.tick()
assert(D.rows[first] and D.rows[second],'Explicit retry renders all retained entries')
D.destroy(); Host.restore()
print('Monitor performance passed: stable view lifetime, change-only redraws, bounded native failures and recovery')
