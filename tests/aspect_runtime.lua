-- Exercise the actual main loop: replacing an aspect also removes its popup.
local S=require('src/core/settings')
local P=require('src/core/presets')
local A=require('src/aspects')
local d=S.defaults();local key,c=S.add(d,'buff')
c.enabled=true;c.buffID='COMBATV2_BUFF_PENANCE_END_CLIENT';c.mode='absolute';c.threshold=30;c.hysteresisMode='absolute';c.hysteresis=5
local db={[S.listKey]=P.export(d)}
PersistentDB={GetString=function(_,k)return db[k]end,GetBool=function(_,k)return db[k]end,
 SetString=function(_,k,v)db[k]=v;return true end,SetBool=function(_,k,v)db[k]=v;return true end}
local callbacks={}
Event=setmetatable({}, {__index=function(t,k)local e={Subscribe=function(_,fn)callbacks[k]=fn end,Unsubscribe=function()end};rawset(t,k,e);return e end})
package.loaded['src/ui/dashboard']={tick=function()end,destroy=function()end,mount=function()end}
package.loaded['src/ui/settings_host']={tick=function()end,restore=function()end,prepare=function()return {}end}
local fired,cleared=0,0
package.loaded['src/audio']={play=function()fired=fired+1 end}
local active={}
package.loaded['src/visual']={active=active,bars={},emit=function(id)active[id]=true end,
 clear=function(id)active[id]=nil;cleared=cleared+1 end,destroy=function()for id in pairs(active)do active[id]=nil end end}
Player={IsAvailable=function()return true end}
var={VarPlayer={},VarClient={}}
for _,name in ipairs(A.names)do var.VarClient[name]={value=-1}end
var.VarClient[c.buffID].value=120*50
A.reset();dofile('main.lua')
callbacks.ContentLayerReady({component={}})
callbacks.Logic({logicTick=100*50})
assert(fired==1 and active[key],'Penance triggers at its remaining-time threshold')
var.VarClient.COMBATV2_BUFF_VAMPYRISM_END_CLIENT.value=900*50
callbacks.Logic({logicTick=101*50})
assert(not active[key] and cleared>0 and fired==1,'Replacement clears the previous popup without firing an expiry alert')
var.VarClient.COMBATV2_BUFF_VAMPYRISM_END_CLIENT.value=-1
callbacks.Logic({logicTick=102*50})
assert(fired==1,'The stale old endpoint never revives')
PluginShutdown()
print('Aspect runtime passed: real main-loop cancellation clears old visual and suppresses false expiry')
