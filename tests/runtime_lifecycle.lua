local S=require('src/core/settings')
local P=require('src/core/presets')
local V=require('src/core/vars')
local d=S.defaults()
local id,c=S.add(d,'health');c.enabled=true;c.threshold=50;c['repeat']=true;c.cooldown=10
local db={[S.listKey]=P.export(d)}
PersistentDB={GetString=function(_,k)return db[k]end,GetBool=function(_,k)return db[k]end,
 SetString=function(_,k,v)db[k]=v;return true end,SetBool=function(_,k,v)db[k]=v;return true end}
local callbacks={}
Event=setmetatable({}, {__index=function(t,k)
 local e={Subscribe=function(_,fn)callbacks[k]=fn end,Unsubscribe=function()callbacks[k]=nil end};rawset(t,k,e);return e
end})
local available=false
Player={IsAvailable=function()return available end}
var={VarPlayer={LIFEPOINTS={value=20},MAXLIFEPOINTS={value=100}}}
local destroys,emitted,stops=0,0,0
local monitor={}
package.loaded['src/ui/dashboard']={tick=function()end,destroy=function()end,
 mount=function(_,data,test)monitor.data=data;monitor.test=test end}
package.loaded['src/ui/settings_host']={tick=function()end,restore=function()end,prepare=function()return {}end}
package.loaded['src/audio']={play=function()emitted=emitted+1 end}
local visual=require('src/visual')
local destroy=visual.destroy
visual.destroy=function()destroys=destroys+1;destroy()end
local prices=require('src/prices')
local stop=prices.stop
prices.stop=function()stops=stops+1;stop()end
dofile('main.lua')
local function tick(t)callbacks.Logic({logicTick=t*50})end
callbacks.ContentLayerReady({})
tick(1000)
assert(destroys==1)
for i=1,100 do tick(1000+i/50)end
assert(destroys==1 and stops==0,'Logged-out ticks must not repeatedly reset or cancel explicit GE tests')
available=true;tick(1003);assert(emitted==1 and visual.conditions[id],'Logic publishes the real engine condition')
tick(1004);assert(emitted==1 and visual.conditions[id],'Condition remains active between repeat sounds')
tick(1);assert(emitted==2,'A restarted clock must rebaseline threshold/cooldown state')
tick(10);assert(emitted==2)
tick(11);assert(emitted==3,'Repeating alert resumes on the new clock')
assert(visual.active[id])
monitor.data.entries[id].enabled=false;tick(12)
assert(not visual.conditions[id] and not visual.active[id],'Pausing clears an existing popup, even outside the monitor callback')
monitor.test(id);tick(12.5)
assert(visual.active[id] and not visual.conditions[id],'Test on a paused alert must stay visible without enabling it')
available=false;tick(13)
local afterLogout=destroys
for i=14,30 do tick(i)end
assert(destroys==afterLogout and next(visual.samples)==nil,'Logout clears samples once')
assert(next(visual.sourceStatuses)==nil and next(visual.conditions)==nil and next(visual.lastFired)==nil,'Logout clears condition and pulse state')
PluginShutdown()
assert(not callbacks.Logic and not callbacks.Draw)
print('Runtime lifecycle passed: bounded logout reset, clock restart, repeat recovery, pause cleanup and shutdown')
