local T=require('src/timers')
local V=require('src/core/vars')
local S=require('src/core/settings')
local P=require('src/core/presets')
local R=require('src/sources')
local E=require('src/core/alerts')
local D=require('src/buff_durations')
local clients,players={},{}
V.adapters.readClientVar=function(name)return clients[name]end
V.adapters.readVar=function(name)return players[name]end
local count,incense,ids=0,0,{}
for _,entry in ipairs(require('src/effect_catalog')) do
 assert(not ids[entry.id],'Unique effect identifiers');ids[entry.id]=true
 assert(T.supports(entry.id) and D.entries[entry.id],'New bindings have selection and automatic references')
 assert(entry.experimental==true,'Untested bindings are identified explicitly')
 if entry.category=='Incense sticks' then incense=incense+1 end
 count=count+1
 local c=S.newAlert('buff');c.buffID=entry.id
 local state={}
 clients[entry.id]=-1
 assert(T.read('buff',c,100,state)==nil,'No expiry at startup')
 clients[entry.id]=(100+120)*50
 local sample=T.read('buff',c,100,state)
 if entry.disabled then
  assert(sample==nil,'Quarantined ambiguous timers never emit samples')
 else
 assert(sample.value==120 and sample.maximum>=120,'Read live endpoint instead of starting from the nominal duration')
 assert(T.read('buff',c,110,state).value==110,'Endpoint clock advances in seconds')
 clients[entry.id]=(111+3600)*50
 assert(T.read('buff',c,111,state).maximum>=3600,'Stacked extensions are not capped at a base duration')
 clients[entry.id]=nil
 assert(T.read('buff',c,112,state)==nil,'Lost data is not an expiry')
 clients[entry.id]=-1
 assert(T.read('buff',c,113,state)==nil,'Lost data clears observed activation')
 end
end
assert(count==264 and incense==18,'Expected expanded catalogue and all exported incense types')
assert(T.catalog.COMBATV2_BUFF_PENANCE_END_CLIENT.category=='Aspects')
assert(T.catalog.COMBATV2_BUFF_VAMPYRISM_END_CLIENT.category=='Aspects')
assert(T.catalog.COMBATV2_DUEL_ARENA_REMOVAL_SCARAB_POWDER_GOLDEN_END_CLIENT.label=='Powder of penance')
assert(not T.supports('COMBATV2_COOLDOWN_MAGIC_SMOKE_TENDRILS_END_CLIENT'),'Cooldown is not Smoke Cloud')
assert(not T.supports('COMBATV2_DEBUFF_AMASCUT_BOSS_ENCOUNTER_CORRUPTION_END_CLIENT'),'Enemy encounter timers excluded')
local filtered=T.filtered('Incense sticks','kwuarm','')
assert(#filtered==2 and filtered[2].label=='Kwuarm incense sticks','Search narrows categories')
local keep=T.filtered('Incense sticks','no match','COMBATV2_BUFF_PENANCE_END_CLIENT')
assert(#keep==2 and keep[2].id=='COMBATV2_BUFF_PENANCE_END_CLIENT','Filtering keeps the selected effect visible')
local c=S.newAlert('buff');c.enabled=true;c.buffID='TARGET_VULNERABILITY';T.configure(c)
local state={};local spec=T.targets[c.buffID]
players[spec.flag]=0
assert(T.read('buff',c,0,state)==nil,'No missing-debuff alerts without a target')
players.NPCTARGET=123;players.PLAYERTARGET=-1
assert(T.read('buff',c,1,state)==nil,'Debounce initial status synchronization')
local missing=T.read('buff',c,3,state)
assert(missing.presenceOnly and missing.value==0 and missing.displayValue:find('missing',1,true))
local fired=0;local engine=E.new(function()fired=fired+1 end)
assert(engine:step('v',c,missing,3) and fired==1)
assert(not engine:step('v',c,missing,4),'No repeat unless configured')
players[spec.flag]=1
local active=T.read('buff',c,5,state)
assert(active.value==100 and active.displayValue:find('active',1,true))
assert(not engine:step('v',c,active,5),'Applied debuff resets alert')
players[spec.flag]=0
assert(T.read('buff',c,6,state)==nil)
assert(engine:step('v',c,T.read('buff',c,8,state),8) and fired==2,'Missing again re-arms independently')
players.NPCTARGET=124
assert(T.read('buff',c,9,state)==nil,'Target switches do not inherit the previous absence duration')
players.PLAYERTARGET=55
assert(T.read('buff',c,12,state)==nil,'No PvP target assistance')
players.PLAYERTARGET=-1;players[spec.flag]=nil;players[spec.packed]=nil
assert(T.read('buff',c,13,state)==nil,'Unknown flags are not interpreted as missing')
players[spec.packed]=0x20000000
assert(T.read('buff',c,14,state).value==100,'Packed named VarPlayer fallback uses exported mask')
local smoke=S.newAlert('buff');smoke.buffID='TARGET_SMOKE_CLOUD';T.configure(smoke)
local other={};players.COMBATV2_TARGET_EFFECTS_8=0x80
assert(T.read('buff',smoke,15,other).value==100,'Smoke Cloud uses its separate exported bit')
players.COMBATV2_TARGET_EFFECTS_8=0
assert(T.read('buff',smoke,16,other)==nil)
assert(T.read('buff',smoke,18,other).value==0)
assert(T.read('buff',smoke,2,other)==nil,'Clock rewind clears missing-status debounce')
-- Presence reminders remain binary even if an old/imported configuration has timer thresholds.
c.mode='absolute';c.threshold=1000;c.direction='above'
assert(not engine:step('safe',c,active,20),'Do not fire on an active target debuff from timer-style settings')
assert(engine:step('safe',c,missing,21),'Presence reminders always mean missing, never a fabricated countdown')
assert(S.title(c)=='Vulnerability missing on NPC target')
local d=S.defaults();S.add(d,'buff',c)
assert(P.decode(P.export(d,'Target reminders')),'Target selection survives sharing')
local source=R.new();players.NPCTARGET=-1
local sample,status=source:read('buff',c,22)
assert(not sample and status=='Waiting for an NPC target','Per-alert source status explains why a reminder is waiting')
local switched={}
local firstEffect=S.newAlert('buff');firstEffect.buffID='COMBATV2_BUFF_PENANCE_END_CLIENT'
clients[firstEffect.buffID]=(100+500)*50
assert(T.read('buff',firstEffect,100,switched))
firstEffect.buffID='COMBATV2_BUFF_VAMPYRISM_END_CLIENT';clients[firstEffect.buffID]=-1
assert(T.read('buff',firstEffect,101,switched)==nil,'Changing effects must not inherit another effect expiry')
print('Expanded effects passed: catalogue coverage, 18 incense types, live endpoint semantics, target flags, debounce, rearming, target switches, missing data, PvP guard and preset sharing')
