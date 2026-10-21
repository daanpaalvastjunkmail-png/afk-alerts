local H=require('src/highlighter')
local c={enabled=true,kind='both',names='spot,tree',match='contains',colour='green',tileSize=1,maxEntities=2}
local npc={isValid=true,displayName='Fishing spot',position={x=1,y=2,z=3}}
local tree={isValid=true,displayName='Willow tree',position={x=4,y=5,z=6},isHidden=false}
local hidden={isValid=true,displayName='Tree',isHidden=true}
local scans=0
NPCList={All=function() scans=scans+1; return {npc,{isValid=true,displayName='Rat'}} end}
LocList={All=function() scans=scans+1; return {hidden,tree} end}
Vector3={new=function(x,y,z) return {x=x,y=y,z=z} end}
local draws={}
ShapeList={Draw=function(args) draws[#draws+1]=args end}
H.reset(); H.tick(c,0)
assert(#H.entities==2 and scans==2)
H.tick(c,0.5); assert(scans==2,'Scan at most once per second')
H.draw(c)
assert(#draws==2 and draws[1].ignoreDepth==false and draws[1].colour==H.colours.green)
assert(#draws[1].shapePositions==4 and #draws[1].shapeLines==8)
npc.isValid=false; draws={}
H.draw(c)
assert(#draws==1 and #H.entities==1,'Discard removed entities')
c.match='exact'
assert(not H.matches('Willow tree',c) and H.matches('Tree',c))
c.names='foo.*'
assert(not H.matches('foobar',c),'Names are plain text, never Lua patterns')
c.names='tree'; c.kind='location'; H.tick(c,1)
assert(#H.entities==0,'Hidden and non-exact objects must not match')
c.match='contains'; H.tick(c,2); assert(#H.entities==1)
c.enabled=false; H.tick(c,3); assert(#H.entities==0)
c.enabled=true; c.names=''; H.tick(c,4); H.draw(c); assert(#H.entities==0)
print('Highlighter checks passed: name matching, geometry depth, rate limiting, entity invalidation and disabling')
