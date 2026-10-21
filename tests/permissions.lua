local V=require('src/core/vars')
local Chat=require('src/chat')
local Prices=require('src/prices')
Plugin,PluginPermissions=nil,nil
local granted,status=V.permission('chatAccess')
assert(not granted and status=='unavailable' and next(V.errors)==nil,'Missing host APIs are unavailable, without callback errors')
assert(not Chat.permission() and V.status.chat=='Chat permission status unavailable')
assert(Prices.permissionStatus()=='HTTP access unavailable')
PluginPermissions={chatAccess=1,httpAccess=2}
local allowed={[1]=false,[2]=false}
Plugin={HasPermission=function(p)return allowed[p]end}
local commands={}
ExecuteConsoleCommand=function(command)
 commands[#commands+1]=command
 assert(command=='ppr rs3_alerts_plugin','Never execute permission-enable/disable commands')
end
Prices.install();Prices.tick(0)
assert(#commands==0,'No startup permission prompt')
V.requestPermissions();V.requestPermissions()
assert(#commands==0,'Native callbacks only queue requests')
Prices.tick(1)
assert(#commands==1 and not Chat.permission(),'Coalesce requests; do not infer consent from command success')
allowed[1]=true
assert(Chat.permission() and Prices.permissionStatus()=='HTTP access disabled','Consent remains independent per permission')
allowed[1]=false;allowed[2]=true
assert(not Chat.permission() and Prices.permissionStatus()=='HTTP access enabled')
ExecuteConsoleCommand=function()return false end
V.requestPermissions();Prices.tick(2)
assert(V.status.permissions:find('command failed',1,true))
ExecuteConsoleCommand=function()error('host rejected')end
V.requestPermissions();Prices.tick(3)
assert(V.status.permissions:find('Plugin Hub',1,true) and next(V.errors)==nil,'Host rejection gives an actionable status')
V.requestPermissions();Prices.stop();Prices.tick(4)
assert(V.permissionRequestPending==nil,'Shutdown discards queued modal actions')
print('Optional permissions passed: missing APIs, queued consent, independent grant/revoke, rejection and shutdown')
