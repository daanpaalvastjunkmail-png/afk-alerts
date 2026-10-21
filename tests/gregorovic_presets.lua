local S=require('src/core/settings')
local P=require('src/core/presets')
local T=require('src/timers')
local E=require('src/core/alerts')
local V=require('src/core/vars')
local writes=0
PersistentDB={SetString=function()writes=writes+1;return true end,SetBool=function()writes=writes+1;return true end}
for _,style in ipairs({'Magic','Melee','Necromancy','Ranged'})do
 local preset=assert(P.resolve('Gregorovic AFK - '..style))
 local d=preset.settings
 assert(#d.entryOrder<=S.maxEntries)
 local effects,types={},{}
 for _,id in ipairs(d.entryOrder)do
  local c=d.entries[id];types[c.type]=c
  if c.type=='buff' then assert(T.supports(c.buffID),c.buffID);effects[c.buffID]=c end
 end
 assert(types.health.enabled and types.health.threshold==40 and types.health['repeat'])
 assert(types.prayer.enabled and types.prayer.threshold==20)
 assert(types.overload.enabled and types.overload.mode=='absolute' and types.overload.threshold==30)
 assert(types.inventory.enabled and types.inventory.threshold==27 and types.inventory.direction=='above')
 assert(types.drop.enabled and types.drop.dropMetric=='ge' and types.drop.threshold==100000 and not types.drop['repeat'])
 assert(not types.familiar.enabled,'Unspecified familiar is optional')
 assert(effects.COMBATV2_DUEL_ARENA_REMOVAL_SCARAB_POWDER_GOLDEN_END_CLIENT.enabled)
 assert(effects.COMBATV2_COOLDOWN_WEAPON_POISON_END_EFFECT_CLIENT.threshold==30)
 assert(not effects.TARGET_VULNERABILITY and not effects.TARGET_SMOKE_CLOUD,'Do not invent manual target-debuff requirements for the AFK method')
 local vampire=effects.COMBATV2_BUFF_VAMPYRISM_END_CLIENT
 assert((vampire~=nil)==(style=='Melee'),'Vampyrism aspect belongs only to Melee; the ranged aura is not the same binding')
 assert(not effects.COMBATV2_BUFF_PENANCE_END_CLIENT,'No conflicting Penance aspect')
 local book=effects.COMBATV2_COOLDOWN_GOD_BOOK_TIMER_END_EFFECT_CLIENT
 assert((book~=nil)==(style~='Melee'))
 if book then assert(book.name==(style=='Necromancy' and 'Scripture of Ful charge' or 'Scripture of Amascut charge'))end
 assert((effects.COMBATV2_INCENSE_BURNER_KWUARM_END_CLIENT~=nil)==(style=='Magic' or style=='Melee'))
 assert((effects.COMBATV2_INCENSE_BURNER_IRIT_END_CLIENT~=nil)==(style~='Necromancy'))
 if style=='Melee' then
  assert(effects.COMBATV2_COOLDOWN_SCRIMSHAW_TIMER_END_EFFECT_CLIENT.enabled)
  assert(not effects.COMBATV2_COOLDOWN_BONFIRE_END_EFFECT_CLIENT.enabled)
 end
 assert(not effects.COMBATV2_COOLDOWN_POISON_END_EFFECT_CLIENT,'Ambiguous poison timer cannot claim the player is poisoned')
 for _,binding in ipairs({'COMBATV2_BUFF_NECROMANCY_DARKNESS_END_CLIENT'})do
  local c=assert(effects[binding]);assert(c.direction=='above' and c.mode=='absolute' and c.threshold==0 and c.hysteresis==0)
  local fired=0;local engine=E.new(function()fired=fired+1 end)
  assert(not engine:step('danger',c,{value=0,maximum=100},0))
  assert(engine:step('danger',c,{value=60,maximum=100},1) and fired==1,'Warn on activation, not expiry')
  assert(not engine:step('danger',c,{value=0,maximum=100},2))
  assert(engine:step('danger',c,{value=60,maximum=100},3) and fired==2,'Removing then reapplying an undesired effect rearms it')
 end
 local timer=effects.COMBATV2_COOLDOWN_WEAPON_POISON_END_EFFECT_CLIENT
 V.adapters.readClientVar=function()return -1 end
 assert(T.read('buff',timer,0,{})==nil,'Never-observed effects cannot assert a missing setup')
 V.adapters.readClientVar=nil
 local file=assert(io.open('presets/gregorovic_'..style:lower()..'.txt'));local code=file:read('*a');file:close()
 assert(code==P.export(d,preset.name,preset.description)..'\n','Packaged import matches the builtin')
 assert(P.decode(code) and #code<8000,'Standalone import fits one share field')
end
assert(writes==0,'Constructing or inspecting included presets never overwrites personal data')
local ambiguous='COMBATV2_COOLDOWN_POISON_END_EFFECT_CLIENT'
assert(T.supports(ambiguous),'Keep old saved presets readable')
assert(not require('src/core/alert_catalog').byID['effect:'..ambiguous],'Unavailable poison detection is not offered as a new alert')
local poison=S.newAlert('buff');poison.buffID=ambiguous;poison.enabled=true;poison.mode='absolute';poison.direction='above';poison.threshold=0;poison.hysteresis=0;poison.hysteresisMode='absolute'
V.adapters.readClientVar=function()return 5000 end
local stale={seen=true,lastTime=0}
local calls=0;local engine=E.new(function()calls=calls+1 end)
assert(T.read('buff',poison,1,stale)==nil and not stale.seen,'Old running poison rows are suppressed even with a positive timer and previous observed state')
assert(not engine:step('poison',poison,T.read('buff',poison,2,stale),2) and calls==0)
local weapon=S.newAlert('buff');weapon.buffID='COMBATV2_COOLDOWN_WEAPON_POISON_END_EFFECT_CLIENT'
assert(T.read('buff',weapon,2,{}).value==98,'Weapon poison timer continues to work')
V.adapters.readClientVar=nil
print('Gregorovic presets passed: four styles, supported bindings, exclusive setup choices, activation warnings and standalone imports')
