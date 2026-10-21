local V=require('src/core/vars')
local D=require('src/diagnostics')
local reads={}
local function namespace(domain)
 return setmetatable({}, {__index=function(_,name)
  reads[#reads+1]=domain..'.'..name
  if name=='SA_ENERGY' then error('Unavailable in this world') end
  return {value=name=='LIFEPOINTS' and 4982 or 9900}
 end})
end
var={VarPlayer=namespace('VarPlayer'),VarClient=namespace('VarClient')}
Player={IsAvailable=function()return false end}
assert(D.capture():find('Log into',1,true) and #reads==0)
Player.IsAvailable=function()return true end
Player.GetLevelGameplay=function()return 99 end
Player.GetLevelCapped=function()return 99 end
SkillType={PRAYER=1,SUMMONING=2}
V.adapters.clock=function()return 123 end
local original=print;local printed={}
print=function(value)printed[#printed+1]=value end
local result=D.capture();print=original
assert(#printed>1 and printed[1]:find('API snapshot',1,true) and result:find('VarPlayer.LIFEPOINTS = 4982',1,true))
assert(result:find('VarPlayer.SA_ENERGY = unavailable',1,true))
assert(result:find('VarClient.CLIENT_TIMER = 9900',1,true))
assert(#reads==#D.playerNames+#D.clientNames,'Bounded read: no variable enumeration or background polling')
print('Diagnostics passed: logged-out guard, bounded probes, missing variable isolation and raw console snapshot')

reads={}; printed={};print=function(value)printed[#printed+1]=value end
local limits=D.captureLimits();print=original
assert(#printed==4 and limits:find('legacyMax=9900',1,true) and limits:find('bonfire=9900',1,true))
assert(limits:find('heightenedSenses=9900',1,true) and limits:find('GameplayLevel=99',1,true))
local expected=0;for _,group in ipairs(D.limitGroups) do expected=expected+#group.fields end
assert(#reads==expected,'Maximum snapshot reads only explicit numeric modifier candidates')
print('Maximum diagnostics passed: grouped boost/cap probes without UI/account enumeration')
