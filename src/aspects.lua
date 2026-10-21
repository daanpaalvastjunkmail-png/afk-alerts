-- Aspects are mutually exclusive. A new live endpoint replaces the previous
-- aspect even when the client leaves that aspect's old endpoint populated.
local V=require('src/core/vars')
local A={names={
 'COMBATV2_MAGIC_ANIMATE_DEAD_END_EFFECT_CLIENT',
 'COMBATV2_BUFF_NECROMANCY_DARKNESS_END_CLIENT',
 'COMBATV2_BUFF_PENANCE_END_CLIENT',
 'COMBATV2_BUFF_VAMPYRISM_END_CLIENT',
 'COMBATV2_BUFF_MAGIC_TEMPORAL_ANOMALY_END_CLIENT',
}}
local known={};for _,name in ipairs(A.names)do known[name]=true end
function A.isAspect(name)return known[name]==true end
function A.reset()A.state=nil end
function A.poll(now)
 if not V.finite(now)then A.reset();return end
 local s=A.state
 if s and s.time==now then return end
 if not s or now<s.time then s={values={},blocked={}};A.state=s end
 local active,changed,values={}, {}, {};local valid=0
 for name,value in pairs(s.values)do values[name]=value end
 for _,name in ipairs(A.names)do
  local value=V.call('readClientVar',name)
  if V.finite(value) and value%1==0 and value>=-1 then
   valid=valid+1;values[name]=value
   if value>now*50 then
    active[#active+1]=name
    if s.values[name]~=value then changed[#changed+1]=name end
   end
  end
 end
 if valid==0 then s.time=now;return end
 -- Never guess from duration: an older stacked aspect can end later than a
 -- newly cast one. Conflicting startup values wait for an observed change.
 if #changed==1 then
  s.winner=changed[1];s.blocked[s.winner]=nil
  for _,name in ipairs(active)do if name~=s.winner then s.blocked[name]=true end end
 elseif #changed>1 then
  s.winner=nil
  for _,name in ipairs(active)do s.blocked[name]=true end
 end
 s.values=values;s.time=now
end
function A.suppressed(name)
 if not known[name]then return false end
 local s=A.state
 return s and (s.blocked[name]==true or (s.winner~=nil and s.winner~=name)) or false
end
return A
