local V = require("src/core/vars")
local E = {}; E.__index=E
function E.new(emit) return setmetatable({states={},emit=emit},E) end
function E:reset(key) self.states[key]=nil end
function E:step(key,c,sample,now)
 if not c.enabled or not sample or not V.finite(sample.value) or not V.finite(now) then
  self:reset(key); return false
 end
 local maximum=sample.maximum
 local x=sample.value
 if not sample.presenceOnly and c.mode=="percent" then
  if not V.finite(maximum) or maximum<=0 then self:reset(key); return false end
  x=x/maximum*100
 end
 local h=c.hysteresis
 if not sample.presenceOnly and c.hysteresisMode~=c.mode then
  if not V.finite(maximum) or maximum<=0 then return false end
  h=c.mode=="percent" and h/maximum*100 or h/100*maximum
 end
 local s=self.states[key] or {active=false}; self.states[key]=s
 local below=sample.presenceOnly or c.direction=="below"
 local threshold=sample.presenceOnly and 50 or c.threshold
 if sample.presenceOnly then h=0 end
 local triggered=(below and x<threshold) or (not below and x>threshold)
 local reset=(below and x>=threshold+h) or (not below and x<=threshold-h)
 -- Reset first; equality remains a safe reset boundary when hysteresis is zero.
 if s.active and reset then s.active=false end
 if not s.active and triggered then
  s.active=true; s.last=now; self.emit(key,c,sample,now); return true
 elseif s.active and c["repeat"] and now-s.last>=math.max(0.1,c.cooldown) then
  s.last=now; self.emit(key,c,sample,now); return true
 end
 return false
end
return E
