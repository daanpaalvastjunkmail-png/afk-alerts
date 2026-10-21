local C=require('src/core/alert_catalog')
local S=require('src/core/settings')
local T=require('src/timers')
local P=require('src/core/presets')
local count,labels=0,{}
for _,entry in ipairs(C.entries)do
 count=count+1
 assert(entry.label~='Buff' and not labels[entry.label:lower()],'No generic Buff category or duplicate labels')
 labels[entry.label:lower()]=true
 local c=assert(C.create(entry.id))
 assert(C.current(c)==entry.id,'Each direct option resolves back to itself')
 if c.type=='buff' then assert(T.supports(c.buffID),'Effect choice configures its binding immediately')end
 if c.type=='chat' then c.chatText='Example message' end
 local d=S.defaults();assert(S.add(d,c.type,c));assert(P.decode(P.export(d,'Catalogue choice')),'All direct choices share and reload')
end
assert(count==283,'Every available ordinary alert and nonduplicate effect is directly selectable')
for kind,names in pairs(T.names)do
 for _,name in ipairs(names)do assert(not C.byID['effect:'..name],'Dedicated timer families do not have duplicate generic entries')end
 assert(C.byID['core:'..kind])
end
for _,entry in pairs(T.catalog)do
 local family=false
 for _,names in pairs(T.names)do for _,name in ipairs(names)do if entry.id==name then family=true end end end
 if entry.disabled then assert(not C.byID['effect:'..entry.id],'Disabled bindings are not offered as new alerts')
 elseif not family then assert(C.byID['effect:'..entry.id],'No available effect is omitted from Add alert')end
end
local incense=C.options('Incense sticks')
for _,category in ipairs(C.categories)do assert(category.id~='all' and category.label~='All alerts','No unbounded All alerts category')end
assert(C.category(S.newAlert('health'))=='Player resources')
assert(C.category(S.newAlert('chat'))=='Chat messages','Chat triggers have a discoverable category')
assert(#C.options('Chat messages')==1 and C.options('Chat messages')[1].kind=='chat')
assert(C.category(C.create('effect:TARGET_SMOKE_CLOUD'))=='Target debuffs')
assert(#incense==18,'The main selector contains all incense choices directly')
local original=S.newAlert('health');original.name='My sound';original.volume=40;original.muted=true;original.sound='my_custom.ogg';original.visuals.flash=true
assert(C.apply(original,'effect:COMBATV2_BUFF_PENANCE_END_CLIENT'))
assert(original.type=='buff' and original.buffID=='COMBATV2_BUFF_PENANCE_END_CLIENT' and original.threshold==30 and original.mode=='absolute')
assert(original.name=='My sound' and original.volume==40 and original.muted and original.sound=='my_custom.ogg' and original.visuals.flash,'Changing selection retains presentation customisations')
original.threshold=9
assert(C.apply(original,C.current(original)) and original.threshold==9,'Reselecting an alert does not reset its settings')
assert(C.apply(original,'core:chat') and original.type=='chat' and original.buffID=='' and original.chatText=='','Old trigger settings do not leak into another alert')
local c=S.newAlert('health')
local timer=C.create('core:overload',c)
assert(timer.sound=='overload.mp3','Untouched default sounds follow the new type')
local target=C.create('effect:TARGET_SMOKE_CLOUD')
assert(target.mode=='percent' and target.threshold==50 and target.direction=='below' and target.hysteresis==0,'Target reminders use missing-status defaults')
local legacy=S.newAlert('buff');legacy.buffID=T.names.antifire[2];legacy.threshold=7
assert(C.current(legacy)=='effect:'..T.names.antifire[2] and legacy.threshold==7,'Legacy single-effect bindings are not silently merged into a family')
assert(not C.create('core:buff'),'No blank generic buff can be created from Add alert')
for query,expected in pairs({['health']='core:health',['health alert']='core:health',eal='core:health',hp='core:health',HP='core:health',ovl='core:overload',afk='core:idle',inv='core:inventory',ad='effect:COMBATV2_MAGIC_ANIMATE_DEAD_END_EFFECT_CLIENT'})do
 local found=false
 for _,entry in ipairs(C.options('Incense sticks',query))do if entry.id==expected then found=true end end
 assert(found,'Global partial/abbreviation search must find '..query..' from another category')
end
assert(#C.options('Aspects','doesnotexist')==0)
print('Unified alert catalogue passed: direct coverage, deduplication, named effects, automatic defaults, legacy preservation and presentation retention')
