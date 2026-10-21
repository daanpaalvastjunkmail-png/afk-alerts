-- Ownership filtering is a fallback, not proof of the source NPC.
local V=require('src/core/vars')
local S=require('src/core/settings')
local R=require('src/sources')
local c=S.defaults().alerts.drop
local count=0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)); count=count+1 end
local function event(owner,n) return {isOwner=owner,objType={id=123,name='Test loot'},count=n} end
R:resetLoot(100)
eq(R:groundLoot(event(true,2),'added',101),false)
eq(R:groundLoot(event(false,2),'added',104),false)
eq(R:groundLoot(event(nil,2),'added',104),false)
eq(R:groundLoot(event(true,2),'added',104),true)
local sample=R:read('drop',c,104)
eq(sample.value,2); eq(sample.message,'Test loot x2')
local first=sample.eventID
eq(R:read('drop',c,105).eventID,first)
eq(R:groundLoot({isOwner=true,objType={id=123,name='Test loot'},oldCount=5,newCount=4},'changed',105),false)
eq(R:groundLoot({isOwner=true,objType={id=123,name='Test loot'},oldCount=5,newCount=8},'changed',105),true)
sample=R:read('drop',c,105); eq(sample.value,3); eq(sample.eventID,first+1)
eq(R:read('drop',c,110),nil)
-- Inventory deltas must never trigger the Loot alert.
V.adapters.inventory=function() return {{id=123,count=2}} end
R:inventory()
V.adapters.inventory=function() return {{id=123,count=5}} end
R:inventory()
eq(R:read('drop',c,111),nil)
c.lootSource='target'
R:groundLoot(event(true,1),'added',112)
eq(R:read('drop',c,112),nil)
c.lootSource='owned_ground'; c.dropMetric='ge'
R:groundLoot(event(true,2),'added',113)
eq(R:read('drop',c,113),nil)
V.adapters.price=function() return 50 end
R:groundLoot(event(true,2),'added',114)
eq(R:read('drop',c,114).value,100)
print(tostring(count)..' loot checks passed')
