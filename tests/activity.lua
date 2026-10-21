local V=require('src/core/vars')
local R=require('src/sources')
local S=require('src/core/settings')
local E=require('src/core/alerts')
local d=S.defaults()
local c=d.alerts.idle; c.enabled=true
local xp=1000
V.adapters.skillXP=function() return xp end
R:resetActivity()
assert(R:read('idle',c,0)==nil)
assert(R:read('idle',c,100)==nil,'Must not alert before observing XP gain')
xp=1010
assert(R:read('idle',c,101).value==0)
local count=0
local engine=E.new(function() count=count+1 end)
assert(not engine:step('idle',c,R:read('idle',c,131),131),'Threshold equality remains safe')
assert(engine:step('idle',c,R:read('idle',c,132),132))
assert(not engine:step('idle',c,R:read('idle',c,140),140),'One alert per idle episode')
xp=1020
assert(not engine:step('idle',c,R:read('idle',c,141),141))
assert(engine:step('idle',c,R:read('idle',c,172),172) and count==2,'XP gain rearms idle alert')
c.skill='MINING'
assert(R:read('idle',c,173)==nil,'Changing skill requires a new XP gain')
xp=1030; assert(R:read('idle',c,174).value==0)
V.adapters.skillXP=function() return nil end
assert(R:read('idle',c,200)==nil and R.activity==nil,'Missing API data clears the episode')
V.adapters.skillXP=function() return 500 end
assert(R:read('idle',c,201)==nil,'Restored data needs new XP')
V.adapters.inventoryState=function() return 28,28 end
local inv=d.alerts.inventory; inv.enabled=true
assert(engine:step('inventory',inv,R:read('inventory',inv,0),0))
V.adapters.inventoryState=function() return 27,28 end
assert(not engine:step('inventory',inv,R:read('inventory',inv,1),1))
V.adapters.inventoryState=function() return 28,28 end
assert(engine:step('inventory',inv,R:read('inventory',inv,2),2),'Freeing a slot rearms inventory warning')
V.adapters.inventoryState=function() return 30,28 end
assert(R:read('inventory',inv,3)==nil,'Reject inconsistent inventory state')
R:resetActivity()
assert(R.activity==nil)
print('Activity checks passed: initial arming, idle timing, XP recovery, skill switching, missing data and inventory reset')
