local V=require('src/core/vars')
local S=require('src/core/settings')
local M=require('src/visual')
local texts,rects={},{}
V.adapters.gameArea=function()return {width=1000,height=800}end
V.adapters.text=function(x,y,text,colour,width)texts[#texts+1]={x=x,y=y,width=width,text=text};return true end
V.adapters.rect=function(x,y,w,h,c)rects[#rects+1]={x=x,y=y,w=w,h=h}end
local listening,dismiss
V.adapters.popupInput=function(enabled,fn)listening=enabled;dismiss=fn end
local d=S.defaults()
local first,a=S.add(d,'inventory');a.enabled=true;a.position='custom';a.bar.x=9000;a.bar.y=9000
M.draw(d,0);assert(#texts==0 and not listening)
M.emit(first,a,{value=28,maximum=28,displayValue='28 / 28 slots',message='Inventory: 28 / 28 slots'},1)
M.draw(d,1)
assert(texts[1].text=='Inventory full' and texts[1].x==232 and texts[1].y==56,'Legacy offscreen coordinates cannot hide the centred popup')
assert(texts[2].text=='28 / 28 slots' and texts[3].text=='Click anywhere to dismiss')
assert(rects[1].x==220 and rects[1].y==48 and rects[1].w==560)
assert(listening and next(M.bars)==nil)
local count=#texts;dismiss();M.draw(d,1.1)
assert(#texts==count and not listening and M.active[first],'Click dismisses only popup visuals, retaining alert state')
local second,b=S.add(d,'health');b.enabled=true
M.emit(second,b,{value=5,maximum=100,message='Low health'},2);M.draw(d,2)
assert(listening and #texts==count+3,'A new alert can show after dismissing an older one')
M.clear(first);assert(not M.active[first] and M.active[second])
local previous=#texts
M.draw(d,3600)
assert(M.active[second] and listening and #texts==previous+3,'Popup must remain visible long after the display timer expires')
dismiss();M.draw(d,3600.1)
assert(next(M.active)==nil and not listening,'Click dismisses and releases an expired popup')
local _,timed=S.add(d,'health');timed.enabled=true;timed.visuals.popup=false;timed.visuals.flash=true;timed.visuals.circle=true
M.emit('timed',timed,{value=1,maximum=100},4000);M.draw(d,4010)
assert(M.active.timed==nil,'Alerts without text popups still expire normally')
M.destroy();assert(next(M.active)==nil)
local target=S.newAlert('buff');target.buffID='TARGET_VULNERABILITY'
assert(M.message(target,{value=0,presenceOnly=true,message='Vulnerability missing on NPC target'})=='Vulnerability missing on NPC target',
 'Missing target debuff has no invented expiry')
target.buffID='COMBATV2_COOLDOWN_OVERLOAD_END_EFFECT_CLIENT'
assert(M.message(target,{value=0})=='Overload expired','Real timer expiry wording is retained')
print('Visual checks passed: centred backed messages, inventory popup, legacy coordinates, click dismissal, new alerts and cleanup')

local danger=S.newAlert('buff');danger.buffID='COMBATV2_COOLDOWN_POISON_END_EFFECT_CLIENT';danger.direction='above';danger.mode='absolute';danger.threshold=0;danger.name='Poisoned - check poison protection'
assert(M.message(danger,{value=60})==danger.name,'Active poison produces a danger warning, not an expires-soon message')
danger.buffID='COMBATV2_BUFF_NECROMANCY_DARKNESS_END_CLIENT';danger.name='Darkness active - remove it for this method'
assert(M.message(danger,{value=600})==danger.name,'Undesired Darkness activation uses the configured warning')
