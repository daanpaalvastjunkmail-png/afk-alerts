local S=require('src/core/settings')
local P=require('src/core/presets')
local C=require('src/chat')
local R=require('src/sources')
local E=require('src/core/alerts')
ChatType={GENERAL=0,ENGINE=4,SPAM=109,PUBLIC=2,PRIVATE_INCOMING=3,PRIVATE_OUTGOING=6,PLUGIN=33,CONSOLE=99,CLANCHANNEL_AFFINED_CHAT=41}
local granted=true
PluginPermissions={chatAccess=1}
Plugin={HasPermission=function(permission) assert(permission==1); return granted end}
local d=S.defaults()
local first,a=S.add(d,'chat'); a.enabled=true; a.chatText='Your inventory is full.'; a.name='Fishing backpack'; a.cooldown=10
local second,b=S.add(d,'chat'); b.enabled=true; b.chatText='shark'; b.chatChannel='public'; b.cooldown=1
local r1,r2=R.new(),R.new()
local function event(message,kind) return {chatMessage=message,chatType=kind or ChatType.GENERAL} end
assert(C.permission())
assert(C.matches(event('<col=ff0000>Your INVENTORY is full.</col>'),a),'Ignore formatting and case by default')
assert(not C.matches(event('Your inventory is full!',ChatType.PUBLIC),a),'Channel restriction')
assert(not C.matches(event('Your inventory is fullx'),a),'Treat punctuation literally')
a.chatCaseSensitive=true; assert(not C.matches(event('Your INVENTORY is full.'),a)); a.chatCaseSensitive=false
a.chatMatch='exact'; assert(not C.matches(event('Notice: Your inventory is full.'),a)); a.chatMatch='contains'
a.chatChannel='any'
for _,kind in ipairs({ChatType.PLUGIN,ChatType.CONSOLE,ChatType.PRIVATE_OUTGOING}) do assert(not C.matches(event(a.chatText,kind),a)) end
a.chatChannel='game'
local emitted={}
local engine=E.new(function(id) emitted[#emitted+1]=id end)
assert(r1:chatMessage(event(a.chatText),a,1)); assert(not r2:chatMessage(event(a.chatText),b,1))
local sample=r1:read('chat',a,1); assert(sample and sample.message==a.chatText)
engine:step(first,a,sample,1); engine:step(first,a,sample,2); assert(#emitted==1)
assert(not r1:chatMessage(event(a.chatText),a,5),'Cooldown applies to new messages')
assert(r1:read('chat',a,6)==nil,'Expired message does not persist')
assert(r1:chatMessage(event(a.chatText),a,11)); sample=r1:read('chat',a,11); assert(sample.eventID==2)
engine:reset(first); engine:step(first,a,sample,11); assert(#emitted==2)
assert(r2:chatMessage(event('shark',ChatType.PUBLIC),b,2),'Separate source/channel state')
granted=false; assert(not C.permission() and not r1:read('chat',a,12),'Revoked permission clears pending data')
local loaded=assert(P.decode(P.export(d,'Chat presets')))
local copy=loaded.settings.entries[loaded.settings.entryOrder[1]]
assert(copy.name==a.name and copy.chatText==a.chatText and copy.chatChannel=='game','Preset round trip')
a.chatText=' '; assert(not P.decode(P.export(d,'Invalid')),'Empty trigger rejected')
a.chatText='shark'; a.chatChannel='fake'; assert(not P.decode(P.export(d,'Invalid')),'Unknown channel rejected')
print('Chat passed: literal matching, channels, permission, cooldown, instance isolation and preset validation')
