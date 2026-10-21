local V=require('src/core/vars')
local P=require('src/prices')
local allowed=false
PluginPermissions={httpAccess=1}
Plugin={urls={ge={}},HasPermission=function(permission)assert(permission==1);return allowed end}
local commands,requests={},{}
ExecuteConsoleCommand=function(command)
 commands[#commands+1]=command
 assert(command=='ppr rs3_alerts_plugin','Request native consent without forcing any permission')
end
HTTPRequest={new=function(base,path)
 assert(base==Plugin.urls.ge)
 local r={path=path}
 function r:Get(fn)self.callback=fn end
 function r:Cancel()self.cancelled=true end
 requests[#requests+1]=r;return r
end}
P.install();P.tick(0)
assert(#commands==0 and #requests==0,'Startup cannot grant permissions or make test requests')
P.testConnection()
assert(#requests==0 and V.status.geTest:find('disabled',1,true),'Test never grants permission implicitly')
P.allowRequests();P.allowRequests()
assert(#commands==0,'Native button only queues the enable action')
P.tick(1)
assert(#commands==1 and #requests==0 and not allowed,'A request never implies permission was granted')
P.tick(10)
assert(#requests==0,'Wait for a human decision, including dialogs open longer than two seconds')
allowed=true;P.tick(11)
assert(#commands==1 and #requests==1,'Actual permission grant starts the requested connection test')
assert(requests[1].path=='/m=itemdb_rs/api/graph/4151.json','Connection test is independent of drop events')
requests[1].callback({successful=false,responseCode=403})
P.tick(13)
assert(#requests==2 and requests[2].path:find('catalogue',1,true))
requests[2].callback({successful=true,responseCode=200,data='{"item":{"id":4151,"current":{"price":"75.1k"}}}'})
P.tick(13.02)
assert(V.status.geTest:find('GE connection OK',1,true) and V.status.geTest:find('75100',1,true))
allowed=false
ExecuteConsoleCommand=function(command)commands[#commands+1]=command end -- Host ignored the command.
P.allowRequests();P.tick(14);P.tick(74.01)
assert(#commands==2 and #requests==2 and V.status.geTest:find('still disabled',1,true),'Do not assume a command returning normally enabled access')
for i=1,100 do P.tick(74.01+i/50)end
assert(#commands==2,'Never retry the enable command without another click')
ExecuteConsoleCommand=function()error('Command rejected')end
P.allowRequests();P.tick(80)
assert(V.status.geTest:find('command failed',1,true))
allowed=true
P.testConnection();P.tick(82)
assert(#requests==3,'Explicit connection test refreshes a cached result')
allowed=false;P.tick(83);assert(requests[3].cancelled,'Revoking HTTP cancels an active request')
requests[3].callback({successful=true,responseCode=200,data='{"daily":{"1000":99999}}'})
assert(P.cache[4151]==nil,'A late callback after revocation cannot cache a price')
P.cache[4151]={loaded=P.time,price=75100}
assert(P.get(4151,'ge',{tradeable=true})==nil,'Revoked HTTP cannot use a previous GE value')
P.cache[4151]=nil
P.stop()
requests[3].callback({successful=true,responseCode=200,data='{"daily":{"1000":99999}}'})
assert(P.cache[4151]==nil and P.probe==nil,'Late callbacks cannot revive a stopped test')
print('GE permission flow passed: explicit native consent, delayed verification, revocation, independent test, fallback, host rejection and shutdown')
