-- Contract tests using functions and fields from the official documentation.
local V=require('src/core/vars')
local H=require('src/host')
local count=0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)); count=count+1 end
local available=true
Player={IsAvailable=function() return available end,GetLevelGameplay=function(skill) eq(skill,0); return 95 end,GetLevelCapped=function() return 99 end}
SkillType={ATTACK=0}
var={VarPlayer={LIFEPOINTS={value=8752}}}
config={Inv={INV=93}}
Inventory={Find=function(id) eq(id,93); return {valid=true,GetSlots=function() return {{obj={id=100},count=3},{obj={id=200},count=1}} end} end}
local resource={}
Plugin={resources={sounds={health=resource}}}
local captured
local instance={}
audio={SoundPlaybackParams={new=function() return {} end},SoundType={SCRIPT=7},AudioBus={MASTER=0,SFX=1},EmitterShape={NONE=4},Play=function(r,params) eq(r,resource); captured=params; return instance end}
H.install()
Player.GetXPUncapped=function(skill) eq(skill,0); return 12345 end
Inventory.Find=function(id) eq(id,93); return {valid=true,usedSlotCount=27,slotCount=28,
 GetSlots=function() return {{obj={id=100},count=3},{obj={id=200},count=1}} end} end
eq(V.call('skillXP','ATTACK'),12345)
local used,capacity=V.call('inventoryState'); eq(used,27); eq(capacity,28)
local value,maximum=V.call('skill','ATTACK'); eq(value,95); eq(maximum,99)
eq(V.call('readVar','LIFEPOINTS'),8752)
eq(V.call('readVar','UNKNOWN_VARIABLE'),nil)
local slots=V.call('inventory'); eq(slots[1].id,100); eq(slots[1].count,3)
eq(V.call('audio','sounds/health.mp3',0.4),instance); eq(captured.volume,0.4); eq(captured.numLoops,0); eq(captured.audioBus,0)
eq(V.call('audio','sounds/health.ogg',0.2),instance); eq(captured.volume,0.2)
eq(V.call('audio','sounds/health.OGG',0.3),instance);eq(captured.volume,0.3)
eq(V.call('audio','sounds/health.Mp3',0.7),instance);eq(captured.volume,0.7)
Plugin.resources.sounds.MyTone=resource
eq(V.call('audio','sounds/MyTone.OGG',0.8),instance);eq(captured.volume,0.8)
Plugin.resources.sounds.basic_saw=resource
eq(V.call('audio','sounds/basic_saw.ogg',0.5),instance)
Plugin.resources={alert_basic_siren=resource}
eq(V.call('audio','sounds/basic_siren.ogg',0.5),instance)
Plugin.resources={sounds={health=resource}}
-- Flat resources must work even when the nested sounds table is absent.
eq(V.call('audio','sounds/health.ogg',0.5,'SFX'),instance); eq(captured.audioBus,1)
Plugin.resources={alert_health=resource}
eq(V.call('audio','sounds/health.mp3',0.6),instance); eq(captured.volume,0.6)
Plugin.resources={}
eq(V.call('audio','sounds/health.mp3',0.6),nil)
assert(V.errors.audio:find('OGG resource not discovered',1,true),'Missing resources need an actionable error')
assert(not V.errors.audio:find('nil value',1,true),'Missing tables must not cause a raw nil-index error')
count=count+2
available=false
eq(V.call('skill','ATTACK'),nil); eq(V.call('inventory'),nil); eq(V.call('readVar','LIFEPOINTS'),nil)
print(tostring(count)..' adapter checks passed')
