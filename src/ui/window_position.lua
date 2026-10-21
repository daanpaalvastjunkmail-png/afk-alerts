-- Window placement is a local preference, independent of alert presets.
local V=require("src/core/vars")
local P={key="rs3_alerts.window_position.v1."}
function P.load(kind,area,width,height,x,y)
 local ok,value=pcall(function()return PersistentDB:GetString(P.key..kind)end)
 if ok and type(value)=="string" then
  local a,b=value:match("^(-?%d+),(-?%d+)$")
  a,b=tonumber(a),tonumber(b)
  if V.finite(a) and V.finite(b) then x,y=a,b end
 end
 return math.max(0,math.min(x,math.max(0,area.width-width))),math.max(0,math.min(y,math.max(0,area.height-height)))
end
function P.save(window)
 if not window or not window.root or not window.positionKind then return end
 local x,y=window.root.x,window.root.y
 if not V.finite(x) or not V.finite(y) then return end
 local value=math.floor(x)..","..math.floor(y)
 if window.savedPosition==value then return end
 local ok,result=pcall(function()return PersistentDB:SetString(P.key..window.positionKind,value)end)
 if ok and result~=false then window.savedPosition=value end
end
function P.tick(window)
 if not window or not window.root then return end
 local x,y=window.root.x,window.root.y
 if x~=window.observedX or y~=window.observedY then
  window.observedX,window.observedY=x,y;window.positionIdle=0
 else
  window.positionIdle=(window.positionIdle or 0)+1
  if window.positionIdle==25 then P.save(window) end
 end
end
return P
