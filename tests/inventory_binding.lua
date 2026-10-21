local V=require('src/core/vars')
local H=require('src/host')
local S=require('src/core/settings')
local R=require('src/sources')
local E=require('src/core/alerts')
Player={IsAvailable=function()return true end}
config={Inv={INV=93}}
local inv
Inventory={Find=function(id)assert(id==93);return inv end}
H.install()
local c=S.newAlert('inventory');c.enabled=true
local fired=0;local engine=E.new(function()fired=fired+1 end);local reader=R.new()
inv=setmetatable({isValid=true,slotCount=28,GetSlots=function()
 local slots={};for i=0,27 do slots[i]={obj={id=100},count=100}end;return slots
end},{__index=function(_,key)if key=='valid' or key=='usedSlotCount' then error('Unknown property '..key)end end})
local sample=reader:read('inventory',c,0)
assert(sample.value==28 and sample.maximum==28,'Alternative validity flag and sparse slot tables are supported')
assert(engine:step('i',c,sample,0) and fired==1,'Actual adapter data fires a full-backpack alert')
inv.GetSlots=function()local slots={};for i=1,27 do slots[i]={obj={id=100},count=1}end;slots[28]={count=0};return slots end
assert(not engine:step('i',c,reader:read('inventory',c,1),1))
inv.GetSlots=function()local slots={};for i=1,28 do slots[i]={obj={id=100},count=1}end;return slots end
assert(engine:step('i',c,reader:read('inventory',c,2),2) and fired==2,'Freeing one slot rearms the alert')
inv={valid=true,slotCount=28,usedSlotCount=2,GetSlots=function()error('Counter path needs no slot scan')end}
assert(reader:read('inventory',c,3).value==2,'Documented counter path remains available')
inv={valid=false,slotCount=28,usedSlotCount=28}
assert(reader:read('inventory',c,4)==nil,'Invalid inventories cannot fire alerts')
inv=nil
assert(reader:read('inventory',c,5)==nil and V.status.inventorySpace=='Backpack data unavailable')
print('Inventory binding passed: validity compatibility, occupied-slot fallback, complete alert/rearm cycle and unavailable data')
