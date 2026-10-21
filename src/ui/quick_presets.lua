-- Compact preset controls shared by the monitor dropdown.
local S=require('src/core/settings')
local P=require('src/core/presets')
local L=require('src/core/preset_library')
local V=require('src/core/vars')
local Q={key='rs3_alerts.quickPreset.selected'}
local function remember()
 pcall(function()PersistentDB:SetString(Q.key,Q.selected or '')end)
end
function Q.sync(d)
 if Q.data~=d then
  Q.data=d;Q.activation=0;Q.pending=nil;Q.deleted=nil;Q.undo=nil;Q.message=nil;Q.slots={}
  local ok,key=pcall(function()return PersistentDB:GetString(Q.key)end)
  Q.selected=ok and key or nil
 end
 local changed=false
 for i=1,8 do local key='slot'..i;if Q.slots[key]~=d.presets[key] then Q.slots[key]=d.presets[key];changed=true end end
 return changed
end
function Q.items(d)
 local items,personal={},{}
 for _,item in ipairs(L.list(d))do if not item.standard then personal[item.name:lower()]=true end end
 for _,item in ipairs(L.list(d))do if not item.standard or not personal[item.name:lower()]then items[#items+1]=item end end
 return items
end
function Q.current(d)
 for _,item in ipairs(Q.items(d))do if item.key==Q.selected then return item end end
end
function Q.choose(item)
 if not item then return end
 Q.selected=item.key;Q.pending=nil;Q.message='Selected '..item.name..' · press Load to apply.';remember()
end
function Q.select(d,item,reset)
 if not item then return nil,'Choose a preset.' end
 local name,err,undo=L.load(d,item.code,reset)
 if undo then Q.activation=Q.activation+1;Q.undo=undo;Q.deleted=nil;Q.selected=item.key;remember()end
 if not name then Q.message=err;return nil,err end
 Q.pending=nil;Q.message='Loaded '..name;return true
end
function Q.save(d,name)
 local item=Q.current(d)
 name=name or (item and item.name)
 if not name then Q.pending={kind='save',name='My preset'};Q.message='Enter a name, then press Enter or Save.';return false end
 local session={data=d,name=name,description=item and item.preset and item.preset.description or '',slot=item and item.slot}
 local slot,err=L.save(d,session,name)
 if not slot then Q.message=err;return nil,err end
 Q.selected='saved:'..slot;Q.pending=nil;Q.deleted=nil;Q.message='Saved '..session.name;remember();return true
end
function Q.rename(d,name)
 local item=Q.current(d)
 if not item then return nil,'Save your alerts as a preset first.' end
 if not item.slot then return Q.save(d,name) end
 local slot,err=L.rename(d,item.slot,name)
 if not slot then Q.message=err;return nil,err end
 Q.selected='saved:'..slot;Q.pending=nil;Q.message='Renamed '..assert(P.decode(d.presets['slot'..slot])).name;remember();return true
end
function Q.remove(d,pending)
 local deleted,err=L.delete(d,pending.slot,pending.code)
 if not deleted then Q.message=err;return nil,err end
 Q.deleted=deleted;Q.undo=nil;Q.selected=nil;Q.pending=nil;Q.message='Preset deleted; alerts are still running.';remember();return true
end
function Q.restore(d,reset)
 if Q.deleted then
  local slot,err=L.restoreDeleted(d,Q.deleted)
  if not slot then Q.message=err;return nil,err end
  Q.deleted=nil;Q.selected='saved:'..slot;remember();Q.message='Preset restored.';return true
 elseif Q.undo then
  local undo=Q.undo;P.restore(d,undo);reset();Q.activation=Q.activation+1
  if not S.save(d)then Q.message='Restored in memory; settings storage failed.';return nil,Q.message end
  Q.undo=nil;Q.selected=nil;remember();Q.message='Previous alerts restored.';return true
 end
end
function Q.import(d,text,reset)
 local session,err=L.import(text)
 if not session then Q.message=err;return nil,err end
 local exists=false
 for _,item in ipairs(L.list(d,'',false))do if item.name:lower()==session.name:lower()then exists=true end end
 local slot
 if exists then
  local copy;copy,err=L.copy(d,session,session.name)
  if copy then session=copy;slot=copy.slot end
 else slot,err=L.save(d,session,session.name)end
 if not slot then Q.message=err;return nil,err end
 return Q.select(d,{key='saved:'..slot,code=d.presets['slot'..slot]},reset)
end
function Q.unmount()
 if Q.nameField and Q.pending then Q.pending.name=Q.nameField:GetText()end
 Q.nameField=nil
end
local function icon(page,kind,x,y)
 if not ui or not ui.Canvas then return end
 local canvas=ui.Canvas.new(page.content);canvas:SetPos(x,y,1,1);canvas:SetSize(24,24);canvas.clickthrough=true
 local gold=0xD7BD7AFF
 if kind=='save' then
  canvas:AddRectangle(3,3,18,18,gold);canvas:AddRectangle(6,4,11,6,0x403B2DFF)
  canvas:AddRectangle(14,5,2,4,gold);canvas:AddRectangle(6,13,12,7,0x403B2DFF)
  canvas:AddRectangle(8,15,8,1,gold);canvas:AddRectangle(8,18,8,1,gold)
 elseif kind=='trash' then
  canvas:AddRectangle(7,7,11,14,gold);canvas:AddRectangle(4,4,17,2,gold);canvas:AddRectangle(10,1,6,2,gold)
  canvas:AddLine(10,10,10,18,1,0x403B2DFF);canvas:AddLine(14,10,14,18,1,0x403B2DFF)
 else
  canvas:AddLine(6,18,18,6,4,gold);canvas:AddLine(5,19,9,18,2,gold)
 end
end
function Q.height()
 -- Routine hints and success messages do not reserve a permanent status row.
 local message=Q.message
 local quiet=not message or message:match('^Selected ') or message:match('^Loaded ') or message:match('^Saved ') or message:match('^Renamed ') or message:match('^Enter a name') or message=='Previous alerts restored.' or message=='Preset restored.' or message=='Preset deleted; alerts are still running.'
 local statusHeight=not quiet and 24 or 0
 return 64+(Q.pending and 32 or 0)+statusHeight,statusHeight,message

end
function Q.mount(page,d,reset,refresh,font,export)
 Q.sync(d)
 local items=Q.items(d);local item=Q.current(d) or items[1]
 -- The initial visible choice is only a selection: opening never loads a preset.
 if item then Q.selected=item.key end
 local choices,byID={},{}
 for _,entry in ipairs(items)do choices[#choices+1]={id=entry.id,label=entry.name,order=#choices+1};byID[entry.id]=entry end
 local height,statusHeight,message=Q.height()
 local function update()refresh()end
 local function action(label,fn,opts)
  opts.absolute=true;opts.yAnchor=1
  local small=label~=''
  page:AddSimpleButton(small and '' or label,function()V.safe(function()Q.unmount();fn();update()end)end,opts)
  if small then
   local text=page:AddText({text=label,font=font,x=opts.x,y=opts.y,xAnchor=opts.xAnchor,yAnchor=1,width=opts.width,height=opts.height,absolute=true,maxLines=1})
   text.clickthrough=true
   if text.AlignTo and ui and ui.AlignMode then text:AlignTo(ui.AlignMode.CENTRE)end
  end
 end
 page:AddComboBox({x=2,y=-height,width=(not Q.pending and (Q.undo or Q.deleted)) and -56 or -6,widthAnchor=1,yAnchor=1,height=26,absolute=true,font=font,tooltip="Choose a preset",entries=choices,selectedID=item and item.id,
  onChange=function(_,id)V.safe(function()if byID[id]then Q.choose(byID[id]);update()end end)end})
 local row=-height+30
 action('Load',function()Q.select(d,Q.current(d),reset)end,{x=2,y=row,width=48,height=28,tooltip='Load selected preset'})
 action('Export',function()if export then export()end end,{x=54,y=row,width=56,height=28,tooltip='Export selected preset / import presets'})
 action('',function()if Q.pending and Q.pending.kind=='rename' then Q.rename(d,Q.pending.name)else Q.save(d,Q.pending and Q.pending.name)end end,{x=-110,xAnchor=1,y=row,width=32,height=28,tooltip='Save preset'})
 icon(page,'save',-107,row+2)
 action('',function()
  Q.pending={kind=item and item.slot and 'rename' or 'save',name=item and item.name or 'My preset'};Q.message='Enter a name, then press Enter or Save.'
 end,{x=-74,xAnchor=1,y=row,width=32,height=28,tooltip='Rename preset'})
 icon(page,'rename',-71,row+2)
 action('',function()
  if item and item.slot then Q.pending={kind='delete',slot=item.slot,code=item.code,name=item.name}end
 end,{x=-38,xAnchor=1,y=row,width=32,height=28,disabled=not(item and item.slot),tooltip='Delete preset'})
 icon(page,'trash',-35,row+2)
 if Q.pending then
  local pending=Q.pending
  if pending.kind=='delete' then
   page:AddText({text='Delete '..pending.name..'?',x=2,y=-34-statusHeight,yAnchor=1,width=-142,widthAnchor=1,height=28,absolute=true,font=font,maxLines=1})
   action('Delete',function()Q.remove(d,pending)end,{x=-138,xAnchor=1,y=-34-statusHeight,width=72,height=28,tooltip='Confirm delete preset'})
  else
   Q.nameField=page:AddTextField({text=pending.name,placeholder="Preset name",font=font,maxLength=80,x=2,y=-34-statusHeight,yAnchor=1,width=-66,widthAnchor=1,height=28,absolute=true,
    onSubmit=function(_,name)V.safe(function()if pending.kind=='rename' then Q.rename(d,name)else Q.save(d,name)end;update()end)end})
  end
  action('Cancel',function()Q.pending=nil end,{x=-62,xAnchor=1,y=-34-statusHeight,width=56,height=28,tooltip='Cancel preset action'})
 elseif Q.undo or Q.deleted then
  action('Undo',function()Q.restore(d,reset)end,{x=-50,xAnchor=1,y=-height,width=44,height=26,tooltip='Undo preset action'})
 end
 if statusHeight>0 then page:AddText({text=message,x=2,y=-24,yAnchor=1,width=-36,widthAnchor=1,height=20,absolute=true,font=font,maxLines=1})end
 return height
end
return Q
