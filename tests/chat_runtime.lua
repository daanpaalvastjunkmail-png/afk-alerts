-- Run the actual event wiring, including granting permission after plugin startup.
local S=require('src/core/settings'); local P=require('src/core/presets')
local d=S.defaults()
local first,a=S.add(d,'chat'); a.enabled=true; a.chatText='Seren spirit appears'; a.name='Spirit'; a.cooldown=10
local second,b=S.add(d,'chat'); b.enabled=true; b.chatText='inventory is full'; b.name='Backpack'; b.cooldown=1
local db={[S.listKey]=P.export(d)}
PersistentDB={GetString=function(_,k)return db[k]end,GetBool=function(_,k)return db[k]end,SetString=function(_,k,v)db[k]=v;return true end,SetBool=function(_,k,v)db[k]=v;return true end}
local callbacks={}; local granted=false
PluginPermissions={chatAccess=1}; Plugin={HasPermission=function()return granted end}
ChatType={GENERAL=0,PLUGIN=33,PUBLIC=2}
Event=setmetatable({}, {__index=function(t,k)
 local e={Subscribe=function(_,fn) if k=='ChatMessage' then assert(granted) end; callbacks[k]=fn end,Unsubscribe=function()callbacks[k]=nil end}; rawset(t,k,e); return e
end})
package.loaded['src/ui/dashboard']={tick=function()end,destroy=function()end}
package.loaded['src/ui/settings_host']={tick=function()end,restore=function()end}
local emitted={}
package.loaded['src/audio']={play=function(_,c)emitted[c.name]=(emitted[c.name] or 0)+1 end}
package.loaded['src/visual']={emit=function()end,clear=function()end,destroy=function()end}
Player={IsAvailable=function()return true end}
dofile('main.lua')
local function tick(t)callbacks.Logic({logicTick=t*50})end
local function message(text)callbacks.ChatMessage({chatType=ChatType.GENERAL,chatMessage=text})end
tick(0); assert(not callbacks.ChatMessage)
granted=true; tick(2); assert(callbacks.ChatMessage,'Granting permission connects without reloading Lua')
message('A Seren spirit appears'); tick(3); assert(emitted.Spirit==1 and not emitted.Backpack)
message('Your inventory is full'); tick(4); assert(emitted.Backpack==1 and emitted.Spirit==1)
message('A Seren spirit appears'); tick(5); assert(emitted.Spirit==1,'Repeated messages respect cooldown')
message('Your inventory is full'); tick(6); assert(emitted.Backpack==2,'New chat event rearms just this entry')
granted=false; message('Your inventory is full'); tick(7); assert(emitted.Backpack==2)
granted=true; tick(13); message('A Seren spirit appears'); tick(14); assert(emitted.Spirit==2)
assert(#require('src/chat').recent(14,'game')>0,'Actual event wiring fills the recent-message picker')
PluginShutdown(); assert(not callbacks.ChatMessage,'Shutdown unsubscribes chat')
assert(#require('src/chat').history==0,'Shutdown releases temporary chat history')
print('Chat runtime passed: delayed permission, real event wiring, per-entry triggers, cooldown and cleanup')
