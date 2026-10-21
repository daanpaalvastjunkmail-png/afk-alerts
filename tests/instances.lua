local S=require('src/core/settings')
local R=require('src/sources')
local V=require('src/core/vars')
local E=require('src/core/alerts')
local d=S.defaults()
local first,a=S.add(d,'health'); a.enabled=true; a.threshold=50
local second,b=S.add(d,'health'); b.enabled=true; b.threshold=10; b.volume=100; b.muted=true
assert(first~=second and a~=b and a.bar~=b.bar and a.visuals~=b.visuals)
a.visuals.flash=true; assert(not b.visuals.flash)
local calls={}
local engine=E.new(function(id) calls[id]=(calls[id] or 0)+1 end)
local function step(value,time)
 engine:step(first,a,{value=value,maximum=100},time)
 engine:step(second,b,{value=value,maximum=100},time)
end
step(80,0); step(40,1)
assert(calls[first]==1 and not calls[second])
step(5,2); assert(calls[first]==1 and calls[second]==1)
step(20,3); step(5,4)
assert(calls[first]==1 and calls[second]==2,'Critical threshold rearms without resetting 50% alert')
engine:reset(second); step(5,5)
assert(calls[first]==1 and calls[second]==3,'Scoped reset leaves another instance active')
local fishing,mining=R.new(),R.new()
local xp={FISHING=100,MINING=200}
V.adapters.skillXP=function(skill) return xp[skill] end
local fish=S.newAlert('idle'); fish.skill='FISHING'
local mine=S.newAlert('idle'); mine.skill='MINING'
assert(not fishing:read('idle',fish,0) and not mining:read('idle',mine,0))
xp.FISHING=110; xp.MINING=210
assert(fishing:read('idle',fish,1).value==0 and mining:read('idle',mine,1).value==0)
xp.FISHING=120
assert(fishing:read('idle',fish,30).value==0 and mining:read('idle',mine,30).value==29,'Each XP alert has its own source baseline')
local ge,alch=R.new(),R.new()
local geConfig=S.newAlert('drop'); geConfig.dropMetric='ge'; geConfig.itemNameFilter='Rune sword'
local alchConfig=S.newAlert('drop'); alchConfig.dropMetric='high_alch'; alchConfig.itemNameFilter='Rune sword'
V.adapters.price=function(_,metric) return metric=='ge' and 100 or 60 end
local event={isOwner=true,objType={id=1,name='Rune sword',cost=100,isStockmarket=true},count=2}
ge:groundLoot(event,'added',1); alch:groundLoot(event,'added',1)
assert(ge:read('drop',geConfig,1).value==200)
assert(alch:read('drop',alchConfig,1).value==120,'Reading one loot source does not consume another alert\'s batch')
assert(ge.lootPending~=alch.lootPending and ge.lootBatches~=alch.lootBatches)
V.adapters.readVar=function(name) if name=='LIFEPOINTS' then return 8000 end end
local unknown=R.new():read('health',S.newAlert('health'),0)
assert(unknown.value==8000 and unknown.maximum==nil,'Never substitute a made-up max health when API data is unavailable')
print('Instance isolation passed: nested settings, thresholds, cooldown state, XP baselines and independent loot valuation')
