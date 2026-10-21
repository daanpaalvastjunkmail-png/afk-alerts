local S=require('src/core/settings')
local P=require('src/core/presets')
local L=require('src/core/preset_library')
local db={}
PersistentDB={SetString=function(_,k,v)db[k]=v;return true end,SetBool=function(_,k,v)db[k]=v;return true end}
local live=S.defaults();local id,c=S.add(live,'health');c.enabled=true;c.threshold=50
local original=P.export(live,'Original')
local session=assert(L.open(original))
session.data.entries[id].threshold=20
assert(live.entries[id].threshold==50,'Editing a preset cannot mutate active alerts')
assert(L.save(live,session,'Boss one')==1)
assert(P.decode(live.presets.slot1).name=='Boss one' and live.entries[id].threshold==50)
session.data.entries[id].threshold=5
assert(L.rename(live,1,'Renamed')==1)
local renamed=assert(P.decode(live.presets.slot1))
assert(renamed.name=='Renamed' and renamed.settings.entries[id].threshold==20,'Rename preserves stored settings, not unsaved draft changes')
local reset=0
assert(L.load(live,live.presets.slot1,function()reset=reset+1 end)=='Renamed')
assert(reset==1 and live.entries[id].threshold==20)
local share=assert(L.export(session,'Shared'))
local imported=assert(L.import(share))
assert(imported.name=='Shared' and imported.data.entries[id].threshold==5 and not imported.slot)
assert(L.save(live,imported,'Elsewhere')==2,'Imported presets get a separate slot')
local sameName=assert(L.open(original))
sameName.data.entries[id].threshold=33
assert(L.save(live,sameName,' elsewhere ')==2,'Saving under an existing name updates the existing preset instead of creating a duplicate')
assert(live.presets.slot3=='' and P.decode(live.presets.slot2).settings.entries[id].threshold==33)
local firstBefore=live.presets.slot1
assert(not L.rename(live,1,'Elsewhere') and live.presets.slot1==firstBefore,'Renaming a different selected preset cannot silently overwrite another preset')

local broken=live.presets.slot1
assert(not L.save(live,session,string.rep('a',81)) and live.presets.slot1==broken)
assert(not L.import('not a preset'))
assert(not L.export(session,'   '),'Blank names must not silently rename a preset')
local full=S.defaults()
for i=1,32 do
 local _,entry=S.add(full,'health');entry.enabled=true;entry.name=string.rep('x',80);entry.sound=string.rep('s',120)..'.ogg';entry.threshold=i
end
local long=P.export(full,'Large preset');assert(#long>8000)
local parts=long:sub(1,8000)..'\n'..long:sub(8001,16000)..'\n'..long:sub(16001)
assert(#assert(L.import(parts)).data.entryOrder==32,'Paged exported presets can be imported without losing split fields')
for i=1,8 do live.presets['slot'..i]=original end
local noSpace=assert(L.open(original))
assert(not L.save(live,noSpace,'Ninth'),'Never overwrite another saved preset implicitly')
local empty=S.defaults();local retry=assert(L.open(original))
local realWrite=PersistentDB.SetString;PersistentDB.SetString=function()return false end
assert(not L.save(empty,retry,'Retry') and empty.presets.slot1=='' and retry.slot==nil,'Failed save cannot consume another slot or overwrite the in-memory library')
PersistentDB.SetString=realWrite
print('Preset library passed: isolated edit/save, rename, load, export/import, page joining, invalid names and full-slot protection')

local collection=S.defaults();S.add(collection,'health')
collection.presets.slot1=P.export(live,'Zulu')
collection.presets.slot2=P.export(live,'Alpha')
local items=L.list(collection)
assert(items[1].name=='Alpha' and items[2].name=='Zulu' and #items==10,'One sorted library includes saved and standard presets')
assert(#L.list(collection,'',false)==2 and #L.list(collection,'AFK')>=1,'Standard presets can be hidden and names searched literally')
local before=P.export(collection,'Running')
local deleted=assert(L.delete(collection,2,collection.presets.slot2))
assert(collection.presets.slot2=='' and P.export(collection,'Running')==before,'Deleting a preset cannot remove running alerts')
assert(not L.delete(collection,101,'x') and not L.delete(collection,1,'stale'),'Protect standards and changed selections')
collection.presets.slot2=P.export(live,'Reused')
assert(L.restoreDeleted(collection,deleted)==3 and collection.presets.slot2:find('Reused',1,true),'Undo uses a free slot without overwriting a replacement')
local selected=assert(L.open(collection.presets.slot1,1))
assert(not L.hasChanges(selected))
selected.data.entries[selected.data.entryOrder[1]].threshold=17
assert(L.hasChanges(selected),'Unsaved alert edits are tracked')
local copy=assert(L.copy(collection,selected,'Zulu'))
assert(copy.slot==4 and copy.name=='Zulu copy' and collection.presets.slot1~=collection.presets.slot4,'Save as copy is independent')
assert(not L.hasChanges(copy),'Saved copies start clean')
local originalSlot=collection.presets.slot1
PersistentDB.SetString=function()return false end
assert(not L.delete(collection,1,originalSlot) and collection.presets.slot1==originalSlot,'Failed deletion retains the preset')
assert(not L.restoreDeleted(collection,{slot=8,code=originalSlot}) and collection.presets.slot8=='','Failed Undo does not create an in-memory preset')
PersistentDB.SetString=realWrite
print('Preset usability checks passed: unified/searchable list, standard filtering, safe delete/undo, isolated copies and dirty drafts')
