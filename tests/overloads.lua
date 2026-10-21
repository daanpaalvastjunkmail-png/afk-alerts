local O=require('src/overloads')
local V=require('src/core/vars')
local S=require('src/core/settings')
local R=require('src/sources')
for _,name in ipairs({'Overloaded','Holy overload','Replenishment overload','Supreme overload','Supreme overload salve',
 'Elder overload','Elder overload salve','Searing overload','Aggroverload','Holy aggroverload','Elder overload active','Overload cauldron'}) do
 assert(O.matches({name=name}),name)
end
assert(O.matches({name='Future variant',family='overload'}))
assert(not O.matches({name='Overload cooldown'}) and not O.matches({name='Antifire'}))
local feed=nil; V.adapters.buffs=function() return feed end
local c=S.newAlert('overload'); local reader=R.new()
assert(reader:read('overload',c,0)==nil,'Missing live API must not create timer values')
feed={}; assert(reader:read('overload',c,1)==nil,'No expiry warning before observing an overload')
feed={{name='Overloaded',remainingSeconds=5,maximumSeconds=360},{name='Elder overload salve',remainingSeconds=100,maximumSeconds=480}}
local sample=reader:read('overload',c,2)
assert(sample.value==100 and sample.maximum==480,'Do not warn while another overload effect remains active')
local other=R.new(); feed={}; assert(other:read('overload',c,3)==nil,'Separate alert must arm independently')
assert(reader:read('overload',c,3).value==0,'Observed effect ending is a valid expiry')
feed=nil; assert(reader:read('overload',c,4)==nil)
feed={}; assert(reader:read('overload',c,5)==nil,'Lost API data clears prior observation')
feed={{name='Elder overload',remainingSeconds=2,maximumSeconds=0}}
assert(reader:read('overload',c,6).maximum==360)
feed={}; assert(reader:read('overload',c,7).maximum==360,'Expired sample retains validated maximum')
feed={{name='Overloaded',remainingSeconds='unknown'}}
assert(reader:read('overload',c,8)==nil,'Malformed timer data must not become an expiry')
feed={}; assert(reader:read('overload',c,9)==nil)
print('Overload contract passed: family variants, overlapping effects, arming and unavailable-feed handling; live API remains unverified')
