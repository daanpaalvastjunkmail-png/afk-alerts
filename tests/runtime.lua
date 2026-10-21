-- Actual main loop with multiple instances; mocks only the client-facing adapters/UI.
local S=require('src/core/settings')
local P=require('src/core/presets')
local d=S.defaults()
local first,a=S.add(d,'health'); a.enabled=true; a.threshold=50
local second,b=S.add(d,'health'); b.enabled=true; b.threshold=10
local saved=P.export(d)
local db={[S.listKey]=saved}
PersistentDB={GetString=function(_,k)return db[k]end,GetBool=function(_,k)return db[k]end,
 SetString=function(_,k,v)db[k]=v;return true end,SetBool=function(_,k,v)db[k]=v;return true end}
local callbacks={}
Event=setmetatable({}, {__index=function(t,k)
 local event={Subscribe=function(_,fn)callbacks[k]=fn end,Unsubscribe=function()end};rawset(t,k,event);return event
end})
local captured,resetLive,testLive
package.loaded['src/ui/dashboard']={tick=function()end,destroy=function()end,
 mount=function(_,data,test,reset) captured=data; resetLive=reset; testLive=test end}
package.loaded['src/ui/settings_host']={tick=function()end,restore=function()end,prepare=function()return {}end}
local emitted={}
package.loaded['src/audio']={play=function(_,c) emitted[c.threshold]=(emitted[c.threshold] or 0)+1 end}
package.loaded['src/visual']={active={},bars={},emit=function()end,clear=function()end,destroy=function()end}
Player={IsAvailable=function()return true end}
var={VarPlayer={LIFEPOINTS={value=80},MAXLIFEPOINTS={value=100}}}
dofile('main.lua')
callbacks.ContentLayerReady({component={}})
local function tick(hp,time)
 var.VarPlayer.LIFEPOINTS.value=hp
 callbacks.Logic({logicTick=time*50})
end
tick(80,0);tick(40,1);assert(emitted[50]==1 and not emitted[10])
tick(5,2);assert(emitted[50]==1 and emitted[10]==1)
resetLive(second);tick(5,3)
assert(emitted[50]==1 and emitted[10]==2,'UI reset of one entry must not reset other entries')
local draft=S.newAlert('health'); draft.threshold=1
testLive('__preview',draft)
assert(#captured.entryOrder==2 and not draft.enabled,'Preview never creates a persisted entry')
S.remove(captured,first);resetLive(first);tick(20,4);tick(5,5)
assert(emitted[50]==1 and emitted[10]==3,'Deletion and continued monitoring remain instance-scoped')
PluginShutdown()
assert(#assert(P.decode(db[S.listKey])).settings.entryOrder==1,'Shutdown persists the exact remaining list')
print('Runtime passed: concurrent health 50/10 alerts, scoped resets, preview isolation, removal and persistence')
