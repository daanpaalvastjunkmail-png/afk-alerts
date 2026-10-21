local V=require('src/core/vars')
local R=require('src/sources')
local S=require('src/core/settings')
local E=require('src/core/alerts')
local values={LIFEPOINTS=4982,MAXLIFEPOINTS=9900}
V.adapters.readVar=function(name) return values[name] end
local reader=R.new()
local c=S.newAlert('health'); c.enabled=true; c.threshold=50
local fired=0
local engine=E.new(function() fired=fired+1 end)
local sample=reader:read('health',c,0)
assert(sample.value==4982 and sample.maximum==9900)
assert(sample.displayValue=='4982 / 9900 HP · 50.3%')
engine:step('health',c,sample,0); assert(fired==0)
values.LIFEPOINTS=4900
engine:step('health',c,reader:read('health',c,1),1); assert(fired==1)
values.LIFEPOINTS=0
assert(reader:read('health',c,2).value==0,'Zero HP remains valid')
for _,invalid in ipairs({-1,0/0,math.huge}) do
 values.LIFEPOINTS=invalid; assert(reader:read('health',c,3)==nil)
end
values.LIFEPOINTS=4982
for _,invalid in ipairs({0,-1,0/0,math.huge}) do
 values.MAXLIFEPOINTS=invalid
 sample=reader:read('health',c,4)
 assert(sample.value==4982 and sample.maximum==nil)
 engine:step('health',c,sample,4); assert(fired==1)
end
values.MAXLIFEPOINTS=nil
assert(reader:read('health',c,5).maximum==nil)
values.LIFEPOINTS=nil; assert(reader:read('health',c,6)==nil)
print('Health passed: exported names, raw HP percentage, zero HP, invalid readings and no fabricated maximum')
