local V=require('src/core/vars')
local S=require('src/core/settings')
local R=require('src/sources')
local P=require('src/prices')
local c=S.defaults().alerts.drop
local n=0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)); n=n+1 end
local function add(id,name,count,cost,time)
 return R:groundLoot({isOwner=true,objType={id=id,name=name,cost=cost,isStockmarket=true},count=count},'added',time)
end
R:resetLoot(0)
c.itemNameFilter='  rune sword  '; c.dropMetric='high_alch'
V.adapters.price=P.get
add(1,'Rune sword',2,1001,4); add(2,'Rune longsword',9,2000,4)
local sample=R:read('drop',c,4)
eq(sample.value,1200); eq(sample.displayValue,'High Alch: 1200 gp')
assert(sample.message:find('Rune sword x2',1,true) and not sample.message:find('longsword',1,true))
n=n+1
c.itemNameFilter=''; c.dropMetric='ge'
local ready=false
local seen={}
V.adapters.price=function(id,metric,entry)
 eq(metric,'ge'); seen[id]=true
 if ready then return id==1 and 100 or 300 end
end
add(1,'Rune sword',2,1001,5); add(2,'Other loot',3,2000,5)
eq(R:read('drop',c,5),nil)
eq(#R.lootBatches,1)
ready=true
sample=R:read('drop',c,12) -- Price arrived after the old 4-second display window.
eq(sample.value,1100)
eq(sample.displayValue,'GE: 1100 gp'); eq(#R.lootBatches,0)
eq(R:read('drop',c,17),nil)
c.itemNameFilter='Rune sword'
seen={}
add(1,'Rune sword',1,1001,18); add(2,'Other loot',4,2000,18)
eq(R:read('drop',c,18).value,100); eq(seen[2],nil)
-- No partial totals when even one matching price is missing.
c.itemNameFilter=''; R:resetLoot(20)
V.adapters.price=function(id) return id==1 and 100 or nil end
add(1,'Rune sword',1,1001,24); add(2,'Other loot',1,2000,24)
eq(R:read('drop',c,24),nil)
eq(R:read('drop',c,85),nil); eq(#R.lootBatches,0)
print(tostring(n)..' loot value/filter checks passed')

R:resetLoot(100)
V.adapters.price=function()return nil,'GE permission required: Edit > Allow GE price requests'end
add(1,'Rune sword',1,1001,104)
local waiting,reason=R:read('drop',c,104)
assert(not waiting and reason:find('permission required',1,true),'Surface missing permissions instead of a generic waiting message')
V.adapters.price=function()return 75100,true end
sample=R:read('drop',c,105)
assert(sample.value==75100 and sample.displayValue=='GE: ≈ 75100 gp','Rounded catalogue prices must be visibly approximate')
local _,after=R:read('drop',c,110)
assert(after=='Waiting for a matching owned ground-item drop','Resolved prices must not leave a stale error message')
