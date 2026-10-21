-- Standalone behaviour tests; no RuneScape client required.
local V=require('src/core/vars')
local S=require('src/core/settings')
local E=require('src/core/alerts')
local R=require('src/sources')
local A=require('src/audio')
local n=0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)); n=n+1 end
local count=0
local e=E.new(function() count=count+1 end)
local c=S.defaults().alerts.health
c.enabled=true; c.threshold=80; c.hysteresis=5
local function step(x,t,max) return e:step('health',c,{value=x,maximum=max or 100},t) end
eq(step(79,0),true); eq(step(81,1),false); eq(step(79,2),false)
step(85,3); eq(step(79,4),true)
c['repeat']=true; eq(step(79,13),false); eq(step(79,14),true)
c.enabled=false; step(79,15); c.enabled=true; eq(step(79,16),true)
eq(e:step('health',c,nil,17),false); eq(step(79,18),true)
c.direction='above'; e:reset('health'); eq(step(81,20),true)
step(75,21); eq(step(81,22),true)
c.mode='absolute'; c.direction='below'; c.threshold=800; c.hysteresisMode='percent'
e:reset('health'); eq(step(799,30,1000),true); step(850,31,1000); eq(step(799,32,1000),true)
c.mode='percent'; eq(step(1,33,0),false)
local slots={{id=1,count=10},{id=2,amount=2}}
V.adapters.inventory=function() return slots end
R:inventory(); eq(next(R.pending),nil)
slots={{id=1,count=5},{id=1,count=5},{id=2,count=2}}; R:inventory(); eq(next(R.pending),nil)
slots={{id=1,count=12}}; R:inventory(); eq(R.pending[1],2)
local drop=S.defaults().alerts.drop
eq(R:read('drop',drop,0),nil)
eq(R:read('drop',drop,5),nil)
slots={{id=1,count=13}}; R:inventory(); drop.dropMetric='value'
eq(R:read('drop',drop,6),nil)
V.adapters.price=function() return 25 end
slots={{id=1,count=15}}; R:inventory(); eq(R:read('drop',drop,7),nil)
local vol
V.adapters.audio=function(_,v) vol=v end
local d=S.defaults();
for _,alert in pairs(d.alerts) do eq(alert.enabled,false) end
d.masterVolume=50; c.volume=80; c.muted=false
A.play(d,c); eq(vol,0.4); vol=nil; d.masterMuted=true; A.play(d,c); eq(vol,nil)
V.adapters.inventory=function() error('Unavailable') end
R:inventory(); eq(R.previous,nil)
local db={}
PersistentDB=setmetatable({}, {__index=function(_,method)
 if method:match('^Set') then return function(_,k,v) db[k]=v end end
 return function(_,k) return db[k] end
end})
local id,instance=S.add(d,'health'); instance.threshold=8752; eq(S.save(d),true); local loaded=S.load(); eq(loaded.entries[loaded.entryOrder[1]].threshold,8752)
Event=nil
local ok=pcall(dofile,'main.lua'); eq(ok,true)
print(tostring(n)..' checks passed')
