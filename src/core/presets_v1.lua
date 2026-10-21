-- Presets are bounded, declarative data. Never execute imported Lua or commands.
local S=require("src/core/settings")
local V=require("src/core/vars")
local P={maxLength=65536}
local function clone(t)
 if type(t)~="table" then return t end
 local r={}; for k,v in pairs(t) do r[k]=clone(v) end; return r
end
local function trim(s) return s:match("^%s*(.-)%s*$") end
local function encode(s) return (tostring(s):gsub("([^%w_.%-])",function(c) return string.format("%%%02X",c:byte()) end)) end
local function decode(s)
 if s:gsub("%%[%x][%x]",""):find("%%") then return nil end
 return (s:gsub("%%(%x%x)",function(x) return string.char(tonumber(x,16)) end))
end
local function leaves(t,path,out)
 for k,v in pairs(t) do
  local key=path.."."..k
  if type(v)=="table" then leaves(v,key,out)
  elseif k~="label" then out[#out+1]=key.."="..encode(v) end
 end
end
function P.export(d,name,description)
 local rows={}; leaves(d.alerts,"alerts",rows); leaves(d.highlighter,"highlighter",rows); table.sort(rows)
 return "RS3ALERTS/1;name="..encode(name or "My preset")..";description="..encode(description or "")..";"..table.concat(rows,";")
end
local enums={chatChannel={any=true,game=true,public=true,private=true,friends=true,clan=true,guest_clan=true},chatMatch={contains=true,exact=true},mode={percent=true,absolute=true},direction={below=true,above=true},
 hysteresisMode={percent=true,absolute=true},position={top_center=true,custom=true},
 dropMetric={count=true,ge=true,high_alch=true},lootSource={owned_ground=true,target=true},
 kind={npc=true,location=true,both=true},match={contains=true,exact=true},
 colour={cyan=true,green=true,yellow=true,red=true,purple=true}}
local skills={}; for _,skill in ipairs(S.skills) do skills[skill.id]=true end; enums.skill=skills
local function locate(settings,path)
 if not path:match("^alerts%.") and not path:match("^highlighter%.") then return nil end
 local parts={}; for segment in path:gmatch("[^.]+") do parts[#parts+1]=segment end
 if table.concat(parts,".")~=path or #parts>4 then return nil end
 local node=settings
 for i=1,#parts-1 do node=node[parts[i]]; if type(node)~="table" then return nil end end
 local key=parts[#parts]
 if key=="label" or node[key]==nil or type(node[key])=="table" then return nil end
 return node,key
end
local function validate(node,key,raw)
 local expected=type(node[key])
 if expected=="boolean" then
  if raw~="true" and raw~="false" then return nil,"expected true or false" end
  return raw=="true"
 elseif expected=="number" then
  local n=tonumber(raw)
  if not V.finite(n) then return nil,"expected a finite number" end
  local min,max=0,1000000000000
  if key=="x" or key=="y" then min,max=-20000,20000
  elseif key=="volume" then max=100
  elseif key=="cooldown" or key=="duration" then min,max=0.1,86400
  elseif key=="reference" or key=="timerMaximum" then min=1
  elseif key=="tileSize" then min,max=0.25,5
  elseif key=="maxEntities" then min,max=1,100
  elseif key=="positionVersion" then min,max=1,1 end
  if n<min or n>max or ((key=="maxEntities" or key=="positionVersion") and n%1~=0) then return nil,"number outside supported range" end
  return n
 else
  if #raw>512 or raw:find("[%z\1-\31\127]") then return nil,"invalid text" end
  if enums[key] and not enums[key][raw] then return nil,"unknown option" end
  if key=="sound" and (not raw:lower():match("%.mp3$") and not raw:lower():match("%.ogg$") or raw:find("[/\\]") or raw:find("..",1,true)) then return nil,"expected a sound filename" end
  return raw
 end
end
function P.decode(text)
 if type(text)~="string" or #text>P.maxLength then return nil,"Preset exceeds 64 KiB" end
 text=trim(text:gsub("^\239\187\191", "")):gsub("\r", "")
 local defaults=S.defaults()
 local result={name="Imported preset",description="",settings={alerts=defaults.alerts,highlighter=defaults.highlighter}}
 local seen,entries,header={},0,false
 for rawRow in text:gmatch("[^;\n]+") do
  local row=trim(rawRow)
  if row~="" and row:sub(1,1)~="#" then
   if not header then
    if row~="RS3ALERTS/1" then return nil,"Expected RS3ALERTS/1 preset code or a built-in activity name" end
    header=true
   else
    local path,raw=row:match("^([%w_.]+)=(.*)$")
    if not path or seen[path] then return nil,"Invalid or duplicate preset field" end
    seen[path]=true; raw=decode(raw)
    if not raw then return nil,"Invalid percent escape in "..path end
    if path=="name" or path=="description" then
     if #raw>(path=="name" and 80 or 512) or raw:find("[%z\1-\31\127]") then return nil,"Invalid preset "..path end
     result[path]=raw
    else
     local node,key=locate(result.settings,path)
     if not node then return nil,"Unknown setting: "..path end
     local value,err=validate(node,key,raw)
     if value==nil then return nil,path..": "..err end
     node[key]=value; entries=entries+1
    end
   end
  end
 end
 if not header or entries==0 then return nil,"Preset contains no settings" end
 if result.name=="" then result.name="Imported preset" end
 return result
end
P.validate=validate
return P
