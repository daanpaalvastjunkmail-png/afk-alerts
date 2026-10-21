local Q=require('src/ui/quick_presets')
local S=require('src/core/settings')
local P=require('src/core/presets')
local L=require('src/core/preset_library')
local db,fail={},false
PersistentDB={GetString=function(_,k)return db[k]end,SetString=function(_,k,v)if fail then return false end;db[k]=v;return true end,SetBool=function()return true end}
local d=S.defaults();local _,health=S.add(d,'health');health.enabled=true;health.threshold=35
Q.sync(d)
assert(#Q.items(d)==8)
assert(Q.save(d)==false and Q.pending.kind=='save','Save current setup asks for a name only once')
assert(Q.save(d,'My combat'))
assert(Q.current(d).name=='My combat' and #Q.items(d)==9)
health.threshold=12
assert(Q.save(d))
assert(P.decode(d.presets.slot1).settings.entries.alert_1.threshold==12,'One click updates the selected saved preset from current alerts')
local boss
for _,item in ipairs(Q.items(d))do if item.key=='standard:boss' then boss=item end end
local resets=0;local reset=function()resets=resets+1 end
assert(Q.select(d,boss,reset) and #d.entryOrder==4 and resets==1)
assert(Q.restore(d,reset) and #d.entryOrder==1 and d.entries[d.entryOrder[1]].threshold==12,'Undo load restores the previous active list')
assert(Q.select(d,boss,reset));assert(Q.save(d))
local personal=Q.current(d)
assert(personal.slot and personal.name=='Bossing','Save included preset creates a personal version')
local matches=0;for _,item in ipairs(Q.items(d))do if item.name=='Bossing' then matches=matches+1 end end
assert(matches==1,'Personal same-name versions replace the included duplicate in the quick selector')
assert(Q.rename(d,'Boss setup') and Q.current(d).name=='Boss setup')
local code=d.presets['slot'..personal.slot]
assert(not Q.rename(d,'My combat') and d.presets['slot'..personal.slot]==code,'Rename collisions preserve both presets')
local active=P.export(d,'Running')
assert(Q.remove(d,{slot=personal.slot,code=code}))
assert(P.export(d,'Running')==active and not Q.current(d),'Deleting a preset keeps the monitor alerts running')
assert(Q.restore(d,reset) and Q.current(d).name=='Boss setup')
local before=S.clone(d.presets);fail=true
assert(not Q.save(d,'Cannot save'))
for k,v in pairs(before)do assert(d.presets[k]==v,'Failed storage does not mutate the library')end
fail=false
local exported=P.export(d,'My combat')
assert(Q.import(d,exported,reset) and Q.current(d).name=='My combat copy','Import with a name collision creates a separate copy')
local selection=db[Q.key]
local nextData=S.clone(d);local baseline=P.export(nextData,'Running')
Q.sync(nextData)
assert(Q.selected==selection and P.export(nextData,'Running')==baseline,'Reopening remembers selection without reloading over unsaved active changes')
-- Inline controls, using the same callbacks as the monitor.
local buttons,combos,fields={},{},{}
local page={content={}}
function page:AddSimpleButton(label,fn,o)label=({['Load selected preset']='Load',['Confirm delete preset']='Delete',['Cancel preset action']='Cancel',['Undo preset action']='Undo'})[o.tooltip] or label;buttons[#buttons+1]={label=label,fn=fn,opts=o}end
function page:AddComboBox(o)combos[#combos+1]=o end
function page:AddText(o)return {content=o.text}end
function page:AddTextField(o)local f={text=o.text};function f:GetText()return self.text end;fields[#fields+1]=f;return f end
local refreshes=0
local function mount()return Q.mount(page,nextData,reset,function()refreshes=refreshes+1 end)end
local function click(label,tooltip)for i=#buttons,1,-1 do local b=buttons[i];if b.label==label and (not tooltip or b.opts.tooltip==tooltip)then b.fn();return end end;error(label)end
assert(mount()==64)
local initial=P.export(nextData,'Running')
local candidate=Q.items(nextData)[#Q.items(nextData)]
assert(combos[#combos].yAnchor==1 and combos[#combos].y==-64,'Preset selector is anchored to the bottom')
for _,entry in ipairs(combos[#combos].entries)do assert(entry.id~=0 and entry.label~='Current alerts')end
combos[#combos].onChange(nil,candidate.id)
assert(P.export(nextData,'Running')==initial,'Choosing a preset does not replace running alerts')
mount();click('Load')
assert(Q.current(nextData).key==candidate.key,'Load applies the selected preset')
Q.selected=selection;mount()
click('','Rename preset');assert(Q.pending.kind=='rename')
assert(mount()==96)
fields[#fields].text='Inline renamed';click('','Save preset')
assert(Q.current(nextData).name=='Inline renamed' and not Q.pending,'Pencil and Save read typed text without Enter')
mount();click('','Delete preset');assert(Q.pending.kind=='delete' and Q.current(nextData))
mount();click('Cancel');assert(Q.current(nextData),'Delete has a cancel step')
mount();click('','Delete preset');mount();click('Delete');assert(Q.deleted)
mount();click('Undo');assert(Q.current(nextData).name=='Inline renamed')
assert(refreshes>0)
print('Quick presets passed: load/save/rename/delete/undo, included-copy protection, collision-safe import, storage failures, remembered selection and inline controls')
