-- Documented ChatMessage payloads only. Never modify or persist chat messages.
local V=require("src/core/vars")
local C={history={},historyLimit=80,historySeconds=60,sequence=0}
C.channels={
 {id="any",label="Any incoming channel"},{id="game",label="Game messages / NPC dialogue"},
 {id="public",label="Public chat"},{id="private",label="Private messages (incoming)"},
 {id="friends",label="Friends chat"},{id="clan",label="Clan chat"},{id="guest_clan",label="Guest clan chat"},
}
local groups={
 game={"GENERAL","GENERAL_LINKABLE","ENGINE","SPAM","NPC_CHAT","TIMED_EVENT","TEMPORARY_EVENT","WORLD_EVENT"},
 public={"PUBLIC","MOD","QUICKCHAT_PUBLIC"},
 private={"PRIVATE_INCOMING","MOD_PRIVATE_INCOMING","QUICKCHAT_PRIVATE_INCOMING"},
 friends={"FRIEND_CHAT","QUICKCHAT_FRIEND_CHAT","FRIEND_CHAT_NOTIFICATION"},
 clan={"CLANCHANNEL_AFFINED_CHAT","CLANCHANNEL_AFFINED_QUICKCHAT","CLANCHANNEL_AFFINED_NOTIFICATION"},
 guest_clan={"CLANCHANNEL_GUEST_CHAT","CLANCHANNEL_GUEST_QUICKCHAT","CLANCHANNEL_GUEST_NOTIFICATION"},
}
C.filterHelp={
 any="For reliable testing, show the relevant chat category. Set Game messages to All (not Filtered) for gameplay messages; enable Public, Private, Friends or Clan chat for messages from those channels.",
 game="Recommended: Game messages = All, not Filtered. Show game messages in your chat tab. Messages suppressed by the server cannot be detected.",
 public="Recommended: Public chat = On and visible in your chat tab. Friends-only or Off may prevent messages from reaching the client.",
 private="Recommended: Private chat = On and visible. Friends-only permits messages only from eligible friends. Outgoing messages do not trigger this channel.",
 friends="Join the relevant Friends Chat and show Friends Chat messages in your chat tab.",
 clan="Show Clan Chat messages in your chat tab and remain connected to your clan channel.",
 guest_clan="Join the guest clan channel and show Guest Clan Chat messages in your chat tab.",
}
function C.permission()
 local granted,status=V.permission("chatAccess")
 V.status.chat=granted and "Connected; waiting for matching messages" or (status=="unavailable" and "Chat permission status unavailable" or "Grant optional Chat access in Plugin Hub permissions")
 return granted
end
local function isType(value,name) return ChatType and ChatType[name]~=nil and value==ChatType[name] end
local function incoming(event)
 if not event or type(event.chatMessage)~="string" or #event.chatMessage>16384 then return false end
 for _,name in ipairs({"PLUGIN","CONSOLE","CONSOLE_ERROR","CONSOLE_BUFFER_REPLACE","PRIVATE_OUTGOING","QUICKCHAT_PRIVATE_OUTGOING"}) do
  if isType(event.chatType,name) then return false end
 end
 return true
end
function C.channelMatches(kind,channel)
 if channel=="any" then return true end
 for _,name in ipairs(groups[channel] or {}) do if isType(kind,name) then return true end end
 return false
end
local function clean(message)return message:gsub("<br%s*/?>"," "):gsub("<[^>]*>",""):gsub("[\r\n\t]"," ")end
function C.clearHistory() C.history={};C.historyTime=nil end
function C.recent(now,channel)
 if not V.finite(now) or not C.permission() then C.clearHistory();return {} end
 if C.historyTime and now<C.historyTime then C.clearHistory() end
 C.historyTime=now
 local kept,result={},{}
 for _,entry in ipairs(C.history)do
  if now-entry.time<C.historySeconds then
   kept[#kept+1]=entry
   if C.channelMatches(entry.kind,channel or "any")then result[#result+1]=entry end
  end
 end
 C.history=kept
 return result
end
function C.tick(now)
 if not V.finite(now) then return end
 if not C.nextHistoryPrune or now<C.nextHistoryPrune-1 or now>=C.nextHistoryPrune then
  C.recent(now,"any");C.nextHistoryPrune=now+1
 end
end
function C.record(event,now)
 C.recent(now,"any")
 if not V.finite(now) or not C.permission() or not incoming(event) then return end
 local message=clean(event.chatMessage)
 if not message:find("%S")then return end
 C.sequence=C.sequence+1
 table.insert(C.history,1,{id=C.sequence,time=now,kind=event.chatType,text=message:sub(1,512),truncated=#message>512})
 while #C.history>C.historyLimit do table.remove(C.history)end
end
function C.matches(event,c)
 if not incoming(event) then return false end
 -- Exclude plugin output, developer-console lines and our own outgoing messages.
 for _,name in ipairs({"PLUGIN","CONSOLE","CONSOLE_ERROR","CONSOLE_BUFFER_REPLACE","PRIVATE_OUTGOING","QUICKCHAT_PRIVATE_OUTGOING"}) do
  if isType(event.chatType,name) then return false end
 end
 if c.chatChannel~="any" then
  local allowed=false
  for _,name in ipairs(groups[c.chatChannel] or {}) do if isType(event.chatType,name) then allowed=true; break end end
  if not allowed then return false end
 end
 local phrase=(c.chatText or ""):match("^%s*(.-)%s*$")
 if phrase=="" then return false end
 local message=clean(event.chatMessage)
 local needle,haystack=phrase,message
 if not c.chatCaseSensitive then needle=needle:lower(); haystack=haystack:lower() end
 local matches=c.chatMatch=="exact" and haystack==needle or c.chatMatch=="contains" and haystack:find(needle,1,true)~=nil
 return matches,message:sub(1,256)
end
return C
