local V=require('src/core/vars')
local P=require('src/prices')
local n=0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)); n=n+1 end
local data='{"daily":{"1000":120,"3000":450,"2000":200},"average":{"4000":999}}'
local price,stamp=P.parseGraph(data); eq(price,450); eq(stamp,3000)
eq(P.parseGraph('{"daily":{}}'),nil)
eq(P.parseGraph('{"daily":{"1000":-1}}'),nil)
eq(P.parseGraph('{"daily":{"1000":"450"}}'),nil)
eq(P.parseGraph('<html>Service unavailable</html>'),nil)
eq(P.highAlch(1001),600); eq(P.highAlch(4),2); eq(P.highAlch(nil),nil)
local allowed=false
PluginPermissions={httpAccess=1}
Plugin={urls={ge='https://secure.runescape.com'},HasPermission=function() return allowed end}
P.install()
eq(P.get(123,'high_alch',{baseCost=1000}),600)
eq(P.get(123,'ge',{tradeable=true}),nil); eq(#P.queue,0)
allowed=true
local requests={}
HTTPRequest={new=function(base,path)
 eq(base,Plugin.urls.ge)
 local r={path=path}
 function r:AddHeader() end
 function r:Get(fn) self.callback=fn end
 function r:Cancel() self.cancelled=true end
 requests[#requests+1]=r
 return r
end}
eq(P.get(123,'ge',{tradeable=true}),nil)
eq(P.get(123,'ge',{tradeable=true}),nil); eq(#P.queue,1)
P.tick(1); eq(#requests,1); eq(requests[1].path,'/m=itemdb_rs/api/graph/123.json')
requests[1].callback({successful=true,responseCode=200,data=data})
eq(P.get(123,'ge',{tradeable=true}),450); eq(#P.queue,0)
P.get(124,'ge',{tradeable=true}); P.tick(2); eq(#requests,1)
P.tick(3); eq(#requests,2)
requests[2].callback({successful=false,responseCode=503,data=''})
eq(P.get(124,'ge',{tradeable=true}),nil); eq(#P.queue,1)
P.tick(5);eq(#requests,3);eq(requests[3].path,'/m=itemdb_rs/api/catalogue/detail.json?item=124')
local detail='{"item":{"id":124,"name":"Test item","current":{"trend":"neutral","price":"75.1k"},"today":{"price":"+2,254"}}}'
requests[3].callback({successful=true,responseCode=200,data=detail})
local guide,approximate=P.get(124,'ge',{tradeable=true});eq(guide,75100);eq(approximate,true)
P.get(125,'ge',{tradeable=true}); P.tick(7); eq(#requests,4)
P.stop(); eq(requests[4].cancelled,true)
requests[4].callback({successful=true,responseCode=200,data=data})
eq(P.cache[125],nil)
local cases={{'12',12,false},{'1,234',1234,false},{'1.2m',1200000,true},{'2.1b',2100000000,true},{'0',0,false}}
for _,case in ipairs(cases)do
 local parsed,rounded=P.parseDetail('{"item":{"id":42,"current":{"price":"'..case[1]..'"},"today":{"price":"999"}}}',42)
 eq(parsed,case[2]);eq(rounded,case[3])
end
for _,bad in ipairs({'-1','1,23','1,,000','1.k','NaN','1t','1e309'})do
 eq(P.parseDetail('{"item":{"id":42,"current":{"price":"'..bad..'"}}}',42),nil)
end
eq(P.parseDetail(detail,999),nil)
eq(P.parseDetail('{"item":{"id":42,"today":{"price":"123"}}}',42),nil)
P.install();P.get(126,'ge',{tradeable=true});P.tick(9)
requests[5].callback({successful=true,responseCode=200,data='<html>unavailable</html>'})
P.tick(11);eq(#requests,6)
requests[6].callback({successful=false,failed=true,responseCode=0,errorCode=7,errorInfo='Connection failed'})
local _,reason=P.get(126,'ge',{tradeable=true})
assert(reason:find('Connection failed',1,true),'Keep the actionable transport failure during retry backoff')
eq(#P.queue,0)
P.get(127,'ge',{tradeable=true});P.tick(13);P.tick(23)
eq(requests[7].cancelled,true)
P.tick(24);eq(#requests,8);assert(requests[8].path:find('catalogue',1,true))
requests[8].callback({successful=true,responseCode=200,data='{"item":{"id":127,"current":{"price":"123"}}}'})
eq(P.get(127,'ge',{tradeable=true}),123)
requests[7].callback({successful=true,responseCode=200,data=data})
eq(P.get(127,'ge',{tradeable=true}),123) -- Ignore the cancelled graph callback.
-- Client clock resets must preserve cache ages, backoff and in-flight timeouts.
P.tick(1000)
P.get(128,'ge',{tradeable=true});P.tick(1000)
local pending=requests[#requests];assert(P.active)
local age=P.time-P.cache[127].loaded
P.failures[129]=P.time+120;P.failureMessages[129]='Retry later'
P.tick(2)
assert(P.time-P.cache[127].loaded==age,'Cached price age survives a clock reset')
assert(P.failures[129]==122 and P.nextRequest==4,'Retry/rate-limit deadlines follow the new clock')
P.tick(11);assert(not pending.cancelled)
P.tick(12);assert(pending.cancelled and not P.active,'In-flight request still times out after ten elapsed seconds')
P.tick(13);local fallback=requests[#requests]
assert(fallback~=pending and fallback.path:find('detail.json',1,true))
fallback.callback({successful=true,responseCode=200,data='{"item":{"id":128,"current":{"price":"88"}}}'})
eq(P.get(128,'ge',{tradeable=true}),88)
P.tick(0/0);eq(P.time,13)
print(tostring(n)..' price checks passed')
