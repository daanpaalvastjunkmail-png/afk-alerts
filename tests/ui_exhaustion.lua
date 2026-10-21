-- Exhausted native IDs must not cause per-frame allocations or window retries.
local V=require('src/core/vars')
local H=require('src/host')
local windows,canvases=0,0
local area={width=1000,height=800}
id={Component={TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP=1}}
ui={Interfaces={GetComponent=function()return area end},Canvas={new=function()
 canvases=canvases+1
 error('Failed to create Layer (category=0 ID=4096) - invalid dynamic ID, expected a value between 0 and 4096')
end}}
prettyui={Window={new=function()windows=windows+1;error('Must not allocate a window')end}}
H.install()
for _=1,1000 do H.beginFrame() end
assert(canvases==1 and V.uiBlocked,'Stop allocation on first exhausted-ID error')
local Host=require('src/ui/settings_host')
for _=1,10 do assert(not pcall(Host.prepare,{},nil,'list')) end
assert(windows==0,'Cog cannot allocate again after known exhaustion')
Host.restore(); H.destroy()
assert(V.status.monitor:find('restart RuneScape',1,true),'Recovery action is explicit')
print('UI exhaustion passed: single failed allocation, blocked window creation and restart guidance')
