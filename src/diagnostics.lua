-- One-shot probes of exported numeric names; account and chat fields are excluded.
local V=require("src/core/vars")
local D={}
D.playerNames={"LIFEPOINTS","MAXLIFEPOINTS","PRAYER_POINTS","LORE_POINTS","SA_ENERGY","LORE_TIMER","LORE_TIMER_2","LORE_TIMER_VAR","LORE_TIMER_VAR_2"}
D.clientNames={"CLIENT_TIMER","COMBATV2_COOLDOWN_OVERLOAD_END_EFFECT_CLIENT","COMBATV2_COOLDOWN_RAND_OVERLOAD_END_EFFECT_CLIENT","COMBATV2_COOLDOWN_DRAGONFIRE_END_EFFECT_CLIENT","COMBATV2_COOLDOWN_SUPER_DRAGONFIRE_END_EFFECT_CLIENT","COMBATV2_COOLDOWN_WILDERNESS_AGGRESSION_POTION_END_EFFECT_CLIENT","COMBATV2_COOLDOWN_FAMILIAR_TIMER_END_EFFECT_CLIENT"}
-- Short grouped readout for validating boosted HUD maxima.
D.limitGroups={
 {label="Health",fields={{"current","LIFEPOINTS"},{"baseMax","MAXLIFEPOINTS"},{"legacyMax","MAXLIFEPOINTS_OLD"},{"bonfire","BONFIRE_HEALTH_BOOST"},{"prayerHP","COMBATV2_PRAYER_BOOST_HITPOINTS"},{"fontLife","ARCH_RELIC_FONT_OF_LIFE_BOOST"},{"powerburst","HERB_POWERBURST_HEALTH_BOOST"}}},
 {label="Adrenaline",fields={{"current","SA_ENERGY"},{"heightenedSenses","ARCH_RELIC_HEIGHTENED_SENSES_BOOST"},{"leagueMax","LEAGUE_RELIC_COMBAT_MAXIMUM_ADRENALINE_INCREASE"},{"leagueTier1","LEAGUE_RELIC_COMBAT_MAXIMUM_ADRENALINE_INCREASE_TIER_1"}}},
 {label="Prayer",fields={{"currentRaw","PRAYER_POINTS"}}},
}
function D.captureLimits()
 local ok,available=pcall(function() return Player.IsAvailable() end)
 if not ok or not available then V.status.diagnostics="Log into a world before reading live maxima"; return V.status.diagnostics end
 local lines={"AFK ALERTS maxima | clock="..tostring(V.call("clock"))}
 for _,group in ipairs(D.limitGroups) do
  local parts={"AFK ALERTS maxima | "..group.label}
  for _,field in ipairs(group.fields) do
   local valid,value=pcall(function() return var.VarPlayer[field[2]].value end)
   parts[#parts+1]=field[1].."="..(valid and V.finite(value) and tostring(value) or "unavailable")
  end
  if group.label=="Prayer" then
   for _,kind in ipairs({"Gameplay","Capped"}) do
    local valid,value=pcall(function() return Player["GetLevel"..kind](SkillType.PRAYER) end)
    parts[#parts+1]=kind.."Level="..(valid and V.finite(value) and tostring(value) or "unavailable")
   end
  end
  lines[#lines+1]=table.concat(parts," | ")
 end
 for _,line in ipairs(lines) do pcall(print,line) end
 V.status.diagnostics="Maximum snapshot printed; compare with HUD while boost is active"
 return table.concat(lines,"\n")
end
function D.capture()
 local lines={"AFK ALERTS API snapshot (raw values; timer units unverified)"}
 local availableOK,available=pcall(function() return Player.IsAvailable() end)
 if not availableOK or not available then
  V.status.diagnostics="Log into a world before reading live values"
  return V.status.diagnostics
 end
 local function add(label,read)
  local ok,value=pcall(read)
  lines[#lines+1]=label.." = "..(ok and V.finite(value) and tostring(value) or "unavailable")
 end
 add("Logic seconds",function() return V.call("clock") end)
 for _,name in ipairs(D.playerNames) do
  add("VarPlayer."..name,function() return var.VarPlayer[name].value end)
 end
 for _,name in ipairs(D.clientNames) do
  add("VarClient."..name,function() return var.VarClient[name].value end)
 end
 for _,name in ipairs({"PRAYER","SUMMONING"}) do
  add(name.." gameplay level",function() return Player.GetLevelGameplay(SkillType[name]) end)
  add(name.." capped level",function() return Player.GetLevelCapped(SkillType[name]) end)
 end
 local used,total=V.call("inventoryState")
 add("Backpack used slots",function()return used end)
 add("Backpack total slots",function()return total end)
 local result=table.concat(lines,"\n")
 for _,line in ipairs(lines) do pcall(print,"AFK ALERTS | "..line) end
 V.status.diagnostics="Snapshot printed to the developer console"
 return result
end
return D
