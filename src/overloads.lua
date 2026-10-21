-- Match the overload effect family, independently of potion item IDs and dose counts.
-- Host binds the exported normal/dungeoneering overload effect-end variables.
local V=require("src/core/vars")
local Duration=require("src/buff_durations")
local O={}
function O.matches(buff)
 if type(buff)~="table" then return false end
 if buff.family=="overload" then return true end
 if type(buff.name)~="string" then return false end
 local name=buff.name:lower()
 if name:find("cooldown",1,true) then return false end
 return name:find("overload",1,true)~=nil
end
function O.read(now,c,state)
 state=state or {}
 local buffs=V.call("buffs")
 if type(buffs)~="table" then
  state.seen=nil; state.lastTime=nil; Duration.reset(state)
  V.status.overload="Live overload timer unavailable"
  return nil
 end
 if state.lastTime and now<state.lastTime then state.seen=nil;Duration.reset(state) end
 state.lastTime=now
 local longest
 local invalid=false
 for _,buff in ipairs(buffs) do
  if O.matches(buff) then
   if not V.finite(buff.remainingSeconds) or buff.remainingSeconds<0 then invalid=true
   elseif not longest or buff.remainingSeconds>longest.remainingSeconds then longest=buff end
  end
 end
 if invalid then
  state.seen=nil; Duration.reset(state); V.status.overload="Invalid overload timer data"; return nil
 end
 if not longest then
  -- Without a previously observed effect, absence must not fabricate an expiry alert.
  if state.seen then
   Duration.maximum(state,0,nil,state.durationIdentity)
   V.status.overload="Observed overload effect ended"
   return {value=0,maximum=state.maximum,message="Overload effect ended",displayValue="Expired"}
  end
  V.status.overload="No overload effect observed"
  return nil
 end
 local base=V.finite(longest.maximumSeconds) and longest.maximumSeconds>0 and longest.maximumSeconds or
  (longest.timerName and Duration.entries[longest.timerName] and Duration.entries[longest.timerName].seconds) or
  (not longest.timerName and 360 or nil)
 local maximum=Duration.maximum(state,longest.remainingSeconds,base,longest.timerName or "overload")
 state.seen=true; state.maximum=maximum
 V.status.overload="Overload family: "..tostring(longest.name or "Overload")
 return {value=longest.remainingSeconds,maximum=maximum,
  message=tostring(longest.name or "Overload").." expires soon",displayValue=string.format("%d:%02d remaining",math.floor(math.ceil(longest.remainingSeconds)/60),math.ceil(longest.remainingSeconds)%60)}
end
return O
