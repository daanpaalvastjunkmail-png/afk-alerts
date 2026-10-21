local T=require('src/timers')
local V=require('src/core/vars')
local S=require('src/core/settings')
local E=require('src/core/alerts')
local Duration=require('src/buff_durations')
local feed={}
V.adapters.readClientVar=function(name)return feed[name] or -1 end
for _,option in ipairs(T.options) do
 if option.id~='' then assert(Duration.entries[option.id],'Every supported timer has an automatic policy') end
end
local c=S.newAlert('buff');c.buffID=T.extra[3];c.timerMaximum=1;c.enabled=true;c.mode='percent';c.threshold=10
local state={}
feed[c.buffID]=(100+600)*50
local sample=T.read('buff',c,100,state)
assert(sample.value==600 and sample.maximum==720,'Animate Dead uses twelve minutes, ignoring old manual settings')
feed[c.buffID]=(101+60)*50
local fired=0;local engine=E.new(function()fired=fired+1 end)
assert(engine:step('a',c,T.read('buff',c,101,state),101) and fired==1,'Percent expiry threshold uses automatic duration')
feed[c.buffID]=(102+1800)*50
assert(T.read('buff',c,102,state).maximum==1800,'Extended or stacked timers expand the reference')
assert(T.read('buff',c,112,state).maximum==1800,'Reference does not shrink with the countdown')
feed[c.buffID]=-1
assert(T.read('buff',c,113,state).maximum==1800,'Expiry retains this activation reference')
feed[c.buffID]=(114+700)*50
assert(T.read('buff',c,114,state).maximum==720,'A new activation after expiry resets its reference')
feed[c.buffID]='bad'
assert(T.read('buff',c,115,state)==nil and state.maximum==nil,'Missing data clears observed duration and arming')
c.buffID=T.extra[5];feed[c.buffID]=(116+100)*50
assert(T.read('buff',c,116,state).maximum==100,'Ambiguous variants use an explicitly observed reference')
c.buffID=T.extra[4];feed[c.buffID]=(117+600)*50
assert(T.read('buff',c,117,state).maximum==720,'Switching to Darkness resets the reference and uses its base')
state.maximum=1800
assert(T.read('buff',c,10,state).maximum==720,'Clock rewind drops the old reference and uses the current base/remainder')
print('Automatic buff durations passed: complete policy coverage, known bases, legacy settings ignored, thresholds, extension, expiry and missing data')
