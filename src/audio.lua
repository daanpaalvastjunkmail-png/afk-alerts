local V=require("src/core/vars")
local A={}
A.builtins={
 {id="health.mp3",label="Sine (built-in)",stem="health"},
 {id="basic_saw.ogg",label="Saw (built-in)",stem="basic_saw"},
 {id="basic_square.ogg",label="Square (built-in)",stem="basic_square"},
 {id="basic_alarm.ogg",label="Alarm (built-in)",stem="basic_alarm"},
 {id="basic_ring.ogg",label="Ring (built-in)",stem="basic_ring"},
 {id="basic_beep.ogg",label="Beep (built-in)",stem="basic_beep"},
 {id="basic_chime.ogg",label="Chime (built-in)",stem="basic_chime"},
 {id="basic_siren.ogg",label="Siren (built-in)",stem="basic_siren"},
 {id="basic_double_alarm.ogg",label="Double Alarm (built-in)",stem="basic_double_alarm"},
 {id="basic_urgent_pulse.ogg",label="Urgent Pulse (built-in)",stem="basic_urgent_pulse"},
}
local legacy={health=true,adrenaline=true,prayer=true,summoning=true,skill=true,familiar=true,overload=true,antifire=true,aggression=true,buff=true,drop=true,basic_triangle=true}
local reserved={};for _,entry in ipairs(A.builtins)do reserved[entry.stem]=true end
function A.isLegacy(name)
 if type(name)~="string" then return false end
 local stem=name:lower():match("^([%w_]+)%.mp3$") or name:lower():match("^([%w_]+)%.ogg$")
 return stem and legacy[stem]==true or false
end
function A.playbackName(name)return A.isLegacy(name) and "health.mp3" or name end
-- Resource paths come from the client, so no operating-system install path is guessed.
function A.soundFolder()
 local ok,path=pcall(function()
  local resources=Plugin.resources
  local sounds=resources.sounds
  local resource=(sounds and sounds.health) or resources.alert_health
  return resource and resource.path
 end)
 if not ok or type(path)~="string" then return nil end
 path=path:gsub("\\","/")
 if not (path:match("^/") or path:match("^%a:/")) then return nil end
 local root=path:match("^(.*)/resources/sounds/[^/]+$") or path:match("^(.*)/resources/alert_[^/]+%.ogg$")
 return root and (root.."/resources/sounds") or nil
end
function A.catalog(selected)
 local entries,seen={},{}
 local function add(name,label)
  if type(name)=="string" and not seen[name] then
   entries[#entries+1]={id=name,label=label or name}; seen[name]=true
  end
 end
 for index,entry in ipairs(A.builtins)do
  -- Keep a saved legacy ID selected without adding an extra built-in choice.
  add(index==1 and A.isLegacy(selected) and selected or entry.id,entry.label)
 end
 local ok,custom=pcall(require,"src/custom_sounds")
 if ok and type(custom)=="table" then
  for _,entry in ipairs(custom) do add(entry.id,entry.label) end
 end
 -- Also discover OGG resources added manually before a resource refresh.
 pcall(function()
  for stem in pairs(Plugin.resources.sounds or {}) do
   if type(stem)=="string" then
    local mp3=stem..".mp3"
    if not reserved[stem] and not legacy[stem] and not seen[mp3] then add(stem..".ogg",stem.." (OGG)") end
   end
  end
 end)
 if selected and not seen[selected] then add(selected,selected.." (saved selection)") end
 table.sort(entries,function(a,b) return a.label:lower()<b.label:lower() end)
 return entries
end
function A.play(settings,c)
 if settings.masterMuted or c.muted then return end
 local volume=math.max(0,math.min(100,settings.masterVolume))/100*math.max(0,math.min(100,c.volume))/100
 if volume<=0 then return end
 -- Accept a filename only; reject paths outside sounds.
 if type(c.sound)~="string" or not (c.sound:lower():match("%.mp3$") or c.sound:lower():match("%.ogg$")) or c.sound:find("[/\\]") or c.sound:find("..",1,true) then return end
 V.call("audio","sounds/"..A.playbackName(c.sound),volume,settings.audioBus or "MASTER")
end
return A
