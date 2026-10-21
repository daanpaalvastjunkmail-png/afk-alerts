-- Named effect-end values use the 50 Hz client Logic clock. CLIENT_TIMER is
-- inactive (-1) in the user's beta snapshots and is deliberately not used.
local V=require("src/core/vars")
local Duration=require("src/buff_durations")
local Aspects=require("src/aspects")
local T={}
T.names={
 overload={"COMBATV2_COOLDOWN_OVERLOAD_END_EFFECT_CLIENT","COMBATV2_COOLDOWN_RAND_OVERLOAD_END_EFFECT_CLIENT"},
 antifire={"COMBATV2_COOLDOWN_DRAGONFIRE_END_EFFECT_CLIENT","COMBATV2_COOLDOWN_SUPER_DRAGONFIRE_END_EFFECT_CLIENT"},
 aggression={"COMBATV2_COOLDOWN_WILDERNESS_AGGRESSION_POTION_END_EFFECT_CLIENT"},
 familiar={"COMBATV2_COOLDOWN_FAMILIAR_TIMER_END_EFFECT_CLIENT"},
}
T.extra={"COMBATV2_COOLDOWN_PRAYER_RENEWAL_END_EFFECT_CLIENT","COMBATV2_COOLDOWN_LORE_RENEWAL_END_EFFECT_CLIENT",
 "COMBATV2_MAGIC_ANIMATE_DEAD_END_EFFECT_CLIENT","COMBATV2_BUFF_NECROMANCY_DARKNESS_END_CLIENT",
 "COMBATV2_COOLDOWN_WEAPON_POISON_END_EFFECT_CLIENT"}
T.options={{id="",label="Choose an effect"},
 {id=T.names.overload[1],label="Overload"},{id=T.names.overload[2],label="Dungeoneering overload"},
 {id=T.names.antifire[1],label="Antifire"},{id=T.names.antifire[2],label="Super antifire"},
 {id=T.names.aggression[1],label="Aggression potion"},{id=T.names.familiar[1],label="Familiar duration"},
 {id=T.extra[1],label="Prayer renewal"},{id=T.extra[2],label="Summoning renewal"},
 {id=T.extra[3],label="Animate Dead"},{id=T.extra[4],label="Darkness"},{id=T.extra[5],label="Weapon poison"}}
T.targets={
 TARGET_VULNERABILITY={label="Vulnerability missing on NPC target",flag="COMBATV2_TARGET_SIDE_PANEL_TARGET_VULNERABILITY",packed="COMBATV2_TARGET_EFFECTS",mask=0x20000000},
 TARGET_SMOKE_CLOUD={label="Smoke Cloud missing on NPC target",flag="COMBATV2_TARGET_SIDE_PANEL_TARGET_MAGIC_SMOKE_CLOUD",packed="COMBATV2_TARGET_EFFECTS_8",mask=0x80},
}
T.catalog={}
for _,option in ipairs(T.options) do
 if option.id~="" then
  local category=(option.label=="Animate Dead" or option.label=="Darkness") and "Aspects" or "Core timers"
  T.catalog[option.id]={id=option.id,label=option.label,category=category}
 end
end
for _,entry in ipairs(require("src/effect_catalog")) do
 T.catalog[entry.id]=entry
 if not entry.disabled then
  T.extra[#T.extra+1]=entry.id
  T.options[#T.options+1]={id=entry.id,label=entry.label}
 end
end
for identifier,entry in pairs(T.targets) do
 T.catalog[identifier]={id=identifier,label=entry.label,category="Target debuffs",presenceOnly=true}
 T.options[#T.options+1]={id=identifier,label=entry.label}
end
-- Keep the empty choice first and names deterministic across reloads.
table.sort(T.options,function(a,b)if a.id==b.id then return false elseif a.id=="" then return true elseif b.id=="" then return false end;if a.label==b.label then return a.id<b.id end;return a.label<b.label end)
T.categories={{id="all",label="All effects"}}
local categorySet={}
for _,entry in pairs(T.catalog) do categorySet[entry.category]=true end
local categories={};for category in pairs(categorySet)do categories[#categories+1]=category end;table.sort(categories)
for _,category in ipairs(categories)do T.categories[#T.categories+1]={id=category,label=category}end
function T.supports(identifier)return T.catalog[identifier]~=nil end
function T.isTarget(identifier)return T.targets[identifier]~=nil end
function T.configure(c)
 if T.isTarget(c.buffID) then c.mode="percent";c.threshold=50;c.direction="below";c.hysteresis=0;c.hysteresisMode="percent" end
end
function T.filtered(category,query,selected)
 query=(query or ""):lower();local result={{id="",label="Choose an effect"}}
 for _,option in ipairs(T.options)do
  local entry=T.catalog[option.id]
  if entry and ((category=="all" or not category or entry.category==category) and (entry.label:lower():find(query,1,true) or entry.id:lower():find(query,1,true)) or option.id==selected) then
   result[#result+1]=option
  end
 end
 return result
end
local function readFlag(entry)
 local value=V.call("readVar",entry.flag)
 if V.finite(value) and (value==0 or value==1) then return value end
 local packed=V.call("readVar",entry.packed)
 if not V.finite(packed) or packed%1~=0 then return nil end
 return (packed & entry.mask)~=0 and 1 or 0
end
function T.readTarget(identifier,now,state)
 local entry=T.targets[identifier]
 if not entry or not V.finite(now) then return nil end
 local npc=V.call("readVar","NPCTARGET")
 local player=V.call("readVar","PLAYERTARGET")
 if not V.finite(npc) or npc<0 or npc%1~=0 or (V.finite(player) and player>=0) then
  state.target=nil;V.status.buff="Waiting for an NPC target";return nil
 end
 local flag=readFlag(entry)
 if flag==nil then state.target=nil;V.status.buff="Target status unavailable";return nil end
 local track=state.target
 if not track or track.npc~=npc or track.identifier~=identifier or now<track.lastTime then
  track={npc=npc,identifier=identifier,lastTime=now};state.target=track
 end
 track.lastTime=now
 if flag==1 then track.missingSince=nil
 else
  track.missingSince=track.missingSince or now
  if now-track.missingSince<2 then V.status.buff="Checking target status...";return nil end
 end
 local name=entry.label:gsub(" missing on NPC target$", "")
 local display=name..(flag==1 and " active on NPC target" or " missing on NPC target")
 V.status.buff=display
 -- Presence is not a duration: never fabricate a countdown from a nominal spell lifetime.
 return {value=flag*100,maximum=100,presenceOnly=true,displayValue=display,message=display}
end
function T.effects(key,now,identifier)
 if not V.finite(now) or now<0 then V.status[key]="Effect clock unavailable";return nil end
 local names=T.names[key]
 if key=="buff" then
  if not T.supports(identifier) or T.isTarget(identifier) then V.status.buff="Choose a supported effect timer name"; return nil end
  if T.catalog[identifier].disabled then
   V.status.buff="Player poison detection unavailable: timer also responds to weapon poison"
   return nil
  end
  names={identifier}
 end
 if not names then return nil end
 local effects={}
 for _,name in ipairs(names) do
  local ending=V.call("readClientVar",name)
  -- Missing data is not proof of expiry. -1/0 mean no active effect.
  if not V.finite(ending) or ending%1~=0 or ending < -1 then V.status[key]="Effect timer unavailable";return nil end
  if ending>0 then
   local remaining=ending/50-now
   if remaining>0 then effects[#effects+1]={name=key,family=key,timerName=name,remainingSeconds=remaining,maximumSeconds=Duration.entries[name].seconds} end
  end
 end
 return effects
end
function T.read(key,c,now,state)
 local binding=key..":"..(c.buffID or "")
 if state.binding~=binding then
  state.binding=binding;state.seen=nil;state.lastTime=nil;state.target=nil;Duration.reset(state)
 end
 if key=="buff" and T.isTarget(c.buffID) then return T.readTarget(c.buffID,now,state) end
 state.target=nil
 if key=="buff" and Aspects.isAspect(c.buffID) then
  Aspects.poll(now)
  if Aspects.suppressed(c.buffID) then
   state.seen=nil;state.lastTime=nil;Duration.reset(state)
   V.status.buff="Inactive · another aspect selected";return nil
  end
 end
 local effects=T.effects(key,now,c.buffID)
 if not effects then state.seen=nil; state.lastTime=nil; Duration.reset(state); return nil end
 if state.lastTime and now<state.lastTime then state.seen=nil;Duration.reset(state) end
 state.lastTime=now
 local remaining,base,identity
 for _,effect in ipairs(effects) do
  if not remaining or effect.remainingSeconds>remaining then
   remaining,base,identity=effect.remainingSeconds,effect.maximumSeconds,effect.timerName
  end
 end
 if remaining then state.seen=true
 elseif not state.seen then V.status[key]="No active effect observed"; return nil
 else remaining=0 end
 local maximum=Duration.maximum(state,remaining,base,identity or state.durationIdentity)
 local seconds=math.ceil(remaining)
 local display=remaining>0 and string.format("%d:%02d remaining",math.floor(seconds/60),seconds%60) or "Expired"
 V.status[key]=display
 return {value=remaining,maximum=maximum,displayValue=display,message=remaining>0 and (c.label.." expires soon") or (c.label.." effect ended")}
end
return T
