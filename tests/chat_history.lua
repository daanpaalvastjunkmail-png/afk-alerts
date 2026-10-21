local C=require('src/chat')
local granted=true
PluginPermissions={chatAccess=1};Plugin={HasPermission=function()return granted end}
ChatType={GENERAL=0,PUBLIC=2,PLUGIN=33,PRIVATE_OUTGOING=6,CONSOLE=99}
local function record(text,time,kind)C.record({chatMessage=text,chatType=kind or 0},time)end
record('<col=ff0000>You already have full prayer.</col>',100)
record('Hello',110,2)
assert(#C.recent(110,'game')==1 and #C.recent(110,'public')==1)
assert(C.recent(110,'game')[1].text=='You already have full prayer.')
for _,kind in ipairs({33,6,99})do record('Ignored',111,kind)end
assert(#C.recent(111,'any')==2,'Plugin, outgoing private and console messages stay excluded')
assert(#C.recent(160,'any')==1,'Messages expire at sixty seconds')
assert(#C.recent(170,'any')==0)
record('Expired without opening editor',171);C.tick(232);assert(#C.history==0,'Logic pruning removes expired text while the editor is closed')
for i=1,100 do record('Message '..i,200)end
assert(#C.history==80 and C.history[1].text=='Message 100','History is bounded and newest first')
granted=false;assert(#C.recent(201,'any')==0 and #C.history==0,'Revoked permission clears all temporary text')
granted=true;record('Clock test',300);assert(#C.recent(1,'any')==0,'Clock restarts discard previous text')
record(string.rep('x',600),2)
assert(C.history[1].truncated and #C.history[1].text==512,'Stored message lengths are bounded')
C.clearHistory();assert(#C.history==0)
print('Chat history passed: channel filter, formatting, expiry, exclusions, memory bounds, revocation and clock reset')
