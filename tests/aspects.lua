local A=require('src/aspects')
local T=require('src/timers')
local V=require('src/core/vars')
local S=require('src/core/settings')
local E=require('src/core/alerts')
local values={};for _,name in ipairs(A.names)do values[name]=-1 end
V.adapters.readClientVar=function(name)return values[name]end
local penance,vamp,dead=A.names[3],A.names[4],A.names[1]
local c=S.newAlert('buff');c.buffID=penance;c.enabled=true;c.mode='absolute';c.threshold=30
local other=S.newAlert('buff');other.buffID=vamp
local old,new={},{};local fired=0;local engine=E.new(function()fired=fired+1 end)
values[penance]=1000*50 -- stacked, ends later than the replacement
assert(T.read('buff',c,100,old).value==900)
values[vamp]=900*50
-- Read the previous aspect first: row order cannot retain its stale timer.
assert(not T.read('buff',c,101,old) and not old.seen)
assert(not engine:step('p',c,nil,101) and fired==0,'Replacing an aspect is not an expiry alert')
assert(T.read('buff',other,101,new).value==799)
local saved=values[penance];values[penance]=nil
assert(not T.read('buff',c,101.1,old),'Missing old endpoint stays inactive')
values[penance]=saved
assert(not T.read('buff',c,101.2,old),'Returning stale data is not a fresh activation')
local snapshot={};for name,value in pairs(values)do snapshot[name]=value;values[name]=nil end
assert(not T.read('buff',c,101.3,old))
for name,value in pairs(snapshot)do values[name]=value end
assert(not T.read('buff',c,101.4,old),'Full transient data loss cannot revive a cancelled aspect')
values[vamp]=-1
assert(T.read('buff',other,102,new).value==0,'Active aspect can expire normally')
assert(not T.read('buff',c,102,old),'The stale old endpoint never resumes when the replacement ends')
values[penance]=1200*50
assert(T.read('buff',c,103,old).value==1097,'A new cast of the original aspect rearms it')
values[dead]=1300*50
assert(not T.read('buff',c,104,old),'Animate Dead also replaces Penance')
values[dead]=-1;values[penance]=-1
assert(not T.read('buff',c,105,old),'Cleared old endpoint cannot cause an expiry after replacement')
A.reset();values[penance]=2000*50;values[vamp]=1900*50
assert(not T.read('buff',c,106,{}),'Conflicting startup timers do not guess the active aspect')
values[penance]=2100*50
assert(T.read('buff',c,107,{}),'Observed activation resolves startup ambiguity')
A.reset();for name in pairs(values)do values[name]=-1 end
values.COMBATV2_DUEL_ARENA_REMOVAL_SCARAB_POWDER_GOLDEN_END_CLIENT=3000*50
local powder=S.newAlert('buff');powder.buffID='COMBATV2_DUEL_ARENA_REMOVAL_SCARAB_POWDER_GOLDEN_END_CLIENT'
values[penance]=2200*50
assert(T.read('buff',c,108,{}) and T.read('buff',powder,108,{}),'Powder is independent of aspect exclusivity')
print('Aspects passed: replacement, row-order independence, stacked timers, no false expiry, reactivation, ambiguous startup and independent powder')
