local V=require('src/core/vars')
local H=require('src/host')
local R=require('src/sources')
local S=require('src/core/settings')
local E=require('src/core/alerts')
local T=require('src/timers')
local available=true
Player={IsAvailable=function()return available end,GetLevelGameplay=function()return 99 end,GetLevelCapped=function()return 99 end}
SkillType={PRAYER=1,SUMMONING=2}
var={VarPlayer={PRAYER_POINTS={value=436},LORE_POINTS={value=990},SA_ENERGY={value=1000}},VarClient={}}
for _,names in pairs(T.names) do for _,name in ipairs(names) do var.VarClient[name]={value=-1} end end
H.install()
local c=S.newAlert('prayer');c.enabled=true;c.threshold=50
local reader=R.new();local sample=reader:read('prayer',c,0)
assert(sample.value==43 and sample.maximum==990 and sample.displayValue:find('4.3%%'))
var.VarPlayer.PRAYER_POINTS.value=6718
local corrected=reader:read('prayer',c,0)
assert(corrected.value==671 and corrected.maximum==990 and corrected.displayValue=='671 / 990 · 67.8%', 'Match the supplied HUD instead of displaying ten times the prayer points')
var.VarPlayer.PRAYER_POINTS.value=436
local fired=0;local engine=E.new(function()fired=fired+1 end)
engine:step('p',c,sample,0);assert(fired==1)
var.VarPlayer.PRAYER_POINTS.value=0
assert(reader:read('prayer',c,1).value==0,'Zero prayer is valid')
assert(reader:read('summoning',S.newAlert('summoning'),1).maximum==990)
assert(reader:read('adrenaline',S.newAlert('adrenaline'),1).value==100)
var.VarPlayer.SA_ENERGY.value=1100
assert(reader:read('adrenaline',S.newAlert('adrenaline'),1).value==110,'Allow adrenaline above the standard 100% mark')
local o=S.newAlert('overload');local overload=R.new()
H.seconds=1788.78;assert(overload:read('overload',o,H.seconds)==nil,'Do not warn on startup without an active effect')
H.seconds=1843.18
var.VarClient[T.names.overload[1]].value=109547
sample=overload:read('overload',o,H.seconds)
assert(math.abs(sample.value-347.76)<0.001 and sample.displayValue=='5:48 remaining','Reproduce supplied elder-overload snapshot')
H.seconds=1853.18
assert(math.abs(overload:read('overload',o,H.seconds).value-337.76)<0.001,'Ten elapsed seconds remove ten seconds')
var.VarClient[T.names.overload[1]].value=110047
assert(math.abs(overload:read('overload',o,H.seconds).value-347.76)<0.001,'Drinking another dose refreshes remaining time')
var.VarClient[T.names.overload[1]].value=-1
assert(overload:read('overload',o,H.seconds).value==0,'Only an observed effect may expire')
local anti=R.new();local a=S.newAlert('antifire')
assert(anti:read('antifire',a,H.seconds)==nil)
var.VarClient[T.names.antifire[1]].value=100000
var.VarClient[T.names.antifire[2]].value=110047
assert(math.abs(anti:read('antifire',a,H.seconds).value-347.76)<0.001,'Use the longest overlapping antifire effect')
var.VarClient[T.names.antifire[2]]=nil
assert(anti:read('antifire',a,H.seconds)==nil,'Lost timer data must not fabricate expiry')
var.VarClient[T.names.antifire[2]]={value=-1}
var.VarClient[T.names.antifire[1]].value=-1
assert(anti:read('antifire',a,H.seconds)==nil,'Lost feed clears observation')
local generic=R.new();local b=S.newAlert('buff');b.buffID='LOGINSCREEN_PASSWORD'
assert(generic:read('buff',b,H.seconds)==nil,'Generic timers accept only supported effect-end names')
b.buffID=T.extra[1];var.VarClient[b.buffID]={value=110047}
assert(generic:read('buff',b,H.seconds).value>0)
var.VarClient[b.buffID]=nil
local lost,reason=generic:read('buff',b,H.seconds)
assert(not lost and reason=='Effect timer unavailable','A missing binding cannot reuse another effect status')
var.VarClient[b.buffID]={value=-1}
assert(not generic:read('buff',b,H.seconds),'An interrupted feed must not fabricate expiry')
local _,inactive=R.new():read('overload',o,H.seconds)
assert(inactive=='No overload effect observed','No effect is an inactive state, not a broken API')
available=false
assert(reader:read('prayer',c,H.seconds)==nil)
assert(overload:read('overload',o,H.seconds)==nil)
print('Live bindings passed: snapshot vitals, adrenaline over 100%, elder timer, countdown, refresh, expiry, overlapping effects and lost-data/logout guards')
