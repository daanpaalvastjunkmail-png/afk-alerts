local V=require('src/core/vars')
package.loaded['src/recording_catalog']={
 {domain='C',id=3732,name='COMBATV2_COOLDOWN_OVERLOAD_END_EFFECT_CLIENT'},
 {domain='P',id=13655,name='LIFEPOINTS'},
 {domain='P',id=-16464,name='BONFIRE_HEALTH_BOOST'},
}
local R=require('src/recorder')
local available=true;Player={IsAvailable=function()return available end}
local reads=0;local raw={COMBATV2_COOLDOWN_OVERLOAD_END_EFFECT_CLIENT=-1,LIFEPOINTS=9900,BONFIRE_HEALTH_BOOST=0}
local function scope()return setmetatable({}, {__index=function(_,name)
 reads=reads+1;assert(raw[name]~=nil,'Explicit allowlist only')
 return {value=raw[name]}
end})end
var={VarClient=scope(),VarPlayer=scope()}
local db={};PersistentDB={SetString=function(_,key,value)db[key]=value;return true end,GetString=function(_,key)return db[key] end}
assert(not R.running);R.tick(0);assert(reads==0,'No reads before opt-in')
R.readsPerTick=1
assert(R.start(0));assert(not R.start(0),'Repeated Start must preserve current recording')
for i=0,3 do local before=reads;R.tick(i/50);assert(reads-before<=1,'Per-tick work is bounded') end
assert(R.changes==2,'Include zero modifier baseline; omit initially inactive timer')
for i=4,99 do R.tick(i/50) end
assert(reads==3,'No rescan before interval')
raw.COMBATV2_COOLDOWN_OVERLOAD_END_EFFECT_CLIENT=109547;raw.BONFIRE_HEALTH_BOOST=495
for i=100,103 do R.tick(i/50) end
assert(R.changes==4)
for i=200,203 do R.tick(i/50) end
assert(R.changes==4,'Stable values generate no duplicate changes')
available=false;R.tick(5);R.tick(5.1);available=true
for i=300,303 do R.tick(i/50) end
assert(R.changes==7,'Login gap starts a fresh baseline without synthetic expiry')
local _,message=R.export();assert(message=='Stop recording first')
assert(R.stop())
local output=assert(R.export());assert(output:sub(1,10)=='RS3DIAG/2;' and not output:find('[\r\n]'))
assert(output:find('START,0',1,true) and output:find('STOP,',1,true))
assert(output:find('GAP,5',1,true) and output:find('109547',1,true))
assert(output:find('BONFIRE_HEALTH_BOOST',1,true) and not output:find('PASSWORD',1,true))
R.result=nil;assert(R.export()==output,'Saved recording survives a module/session reload')
local before=reads;R.tick(20);assert(reads==before,'Stopped recorder performs no work')
assert(R.start(20));R.maxSeconds=1;R.tick(21)
assert(not R.running and R.export():find('time-limit',1,true))
assert(R.start(30));R.tick(29);assert(not R.running and R.export():find('clock-reset',1,true))
assert(R.start(40));R.maxSeconds=1200;R.maxBytes=230
for i=2000,2200 do R.tick(i/50) end
assert(not R.running and #R.export()<=R.maxBytes and R.export():find('size-limit',1,true))
local prior=R.export()
R.maxBytes=48000;assert(R.start(50));R.tick(50)
local oldSetter=PersistentDB.SetString
PersistentDB.SetString=function()return false end
R.stop();PersistentDB.SetString=oldSetter;R.result=nil
assert(R.export()==prior,'Failed save must retain the previous complete recording')
available=false;assert(not R.start(55))
R.result='RS3DIAG/1'
local incomplete,incompleteError=R.export();assert(not incomplete and incompleteError:find('incomplete',1,true))
print('Recorder passed: opt-in, bounded reads/storage, changes only, inactive baseline, logout gaps, saved export and automatic stops')
