-- World-space tile outlines only. No entity visibility or game state is modified.
local V=require("src/core/vars")
local H={entities={},nextScan=0,count=0}
H.colours={cyan=0x33DDFFFF,green=0x44EE66FF,yellow=0xFFE044FF,red=0xFF5555FF,purple=0xCC77FFFF}
local function trim(s) return s:match("^%s*(.-)%s*$") end
function H.matches(name,c)
 if type(name)~="string" then return false end
 name=name:lower()
 for rawToken in c.names:gmatch("[^,]+") do
  local token=trim(rawToken):lower()
  if token~="" and ((c.match=="exact" and name==token) or (c.match=="contains" and name:find(token,1,true))) then return true end
 end
 return false
end
function H.reset() H.entities={}; H.nextScan=0; H.count=0; H.signature=nil; H.shape=nil end
function H.tick(c,now)
 if not c.enabled or trim(c.names)=="" then H.reset(); return end
 local signature=c.kind..":"..c.names..":"..c.match..":"..tostring(c.maxEntities)
 if signature~=H.signature then H.entities={}; H.nextScan=0; H.signature=signature end
 if now<H.nextScan then return end
 H.nextScan=now+1; H.entities={}
 local limit=math.min(100,math.max(1,c.maxEntities))
 local function collect(list,isLocation)
  local ok,entities=pcall(function() return list.All() end)
  if not ok or type(entities)~="table" then V.status.highlighter="Entity list unavailable"; return end
  for _,entity in ipairs(entities) do
   if #H.entities>=limit then break end
   local valid,match=pcall(function()
    return entity.isValid and (not isLocation or not entity.isHidden) and H.matches(entity.displayName,c)
   end)
   if valid and match then H.entities[#H.entities+1]={entity=entity,isLocation=isLocation} end
  end
 end
 if c.kind=="npc" or c.kind=="both" then collect(NPCList) end
 if c.kind=="location" or c.kind=="both" then collect(LocList,true) end
 H.count=#H.entities
 V.status.highlighter=tostring(H.count).." matching entities (visible world geometry only)"
end
function H.draw(c)
 if not c.enabled or #H.entities==0 then return end
 local size=math.max(0.25,math.min(5,c.tileSize))
 if not H.shape or H.shapeSize~=size then
  local r=size*256
  H.shape={Vector3.new(-r,30,-r),Vector3.new(r,30,-r),Vector3.new(r,30,r),Vector3.new(-r,30,r)}
  H.shapeSize=size
 end
 -- Revalidate cached handles every frame; never use removed entities.
 for i=#H.entities,1,-1 do
  local entry=H.entities[i]
  local entity=entry.entity
  local ok,valid=pcall(function()
   if not entity.isValid or (entry.isLocation and entity.isHidden) or not H.matches(entity.displayName,c) then return false end
   ShapeList.Draw{shapePositions=H.shape,shapeLines={0,1,1,2,2,3,3,0},
    translation=entity.position,ignoreDepth=false,lineWidth=3,colour=H.colours[c.colour] or H.colours.cyan}
   return true
  end)
  if not ok or not valid then table.remove(H.entities,i) end
  if not ok then V.report("highlighter",valid) end
 end
end
return H
