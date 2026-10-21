-- Researched base durations and shared-timer variants. See BUFF_DURATIONS.md.
-- A base duration is not a substitute for the live effect-end timestamp.
local D={}
D.entries={
 COMBATV2_COOLDOWN_OVERLOAD_END_EFFECT_CLIENT={seconds=360,description="Overload: 6-minute base; longer live timers extend the reference automatically."},
 COMBATV2_COOLDOWN_RAND_OVERLOAD_END_EFFECT_CLIENT={description="Dungeoneering overload: automatic observed duration; original duration is not identified by this binding."},
 COMBATV2_COOLDOWN_DRAGONFIRE_END_EFFECT_CLIENT={seconds=360,description="Antifire: 6-minute base; extensions follow the live timer."},
 COMBATV2_COOLDOWN_SUPER_DRAGONFIRE_END_EFFECT_CLIENT={description="Super antifire: 6 minutes, or 12 minutes for extended; shared binding uses the observed duration."},
 COMBATV2_COOLDOWN_WILDERNESS_AGGRESSION_POTION_END_EFFECT_CLIENT={seconds=360,description="Aggression: 6-minute base; extensions follow the live timer."},
 COMBATV2_COOLDOWN_FAMILIAR_TIMER_END_EFFECT_CLIENT={description="Familiar lifespan varies. Percentages use the longest remaining duration observed for this active familiar timer."},
 COMBATV2_COOLDOWN_PRAYER_RENEWAL_END_EFFECT_CLIENT={description="Prayer renewal: 5:10 normally, 6:00 in combination potions; shared binding uses the observed duration."},
 COMBATV2_COOLDOWN_LORE_RENEWAL_END_EFFECT_CLIENT={seconds=360,description="Summoning renewal: 6-minute base; extensions follow the live timer."},
 COMBATV2_MAGIC_ANIMATE_DEAD_END_EFFECT_CLIENT={seconds=720,description="Animate Dead: 12-minute base; longer live timers extend the reference automatically."},
 COMBATV2_BUFF_NECROMANCY_DARKNESS_END_CLIENT={seconds=720,description="Darkness: 12-minute base; longer live timers extend the reference automatically."},
 COMBATV2_COOLDOWN_WEAPON_POISON_END_EFFECT_CLIENT={description="Weapon poison variants: 2:30, 5:00, 10:00 or 12:00. Shared binding uses the observed duration."},
}
for _,entry in ipairs(require("src/effect_catalog")) do
 D.entries[entry.id]={seconds=entry.seconds,description=entry.disabled and "Player poison detection is disabled: this ambiguous timer also responds to weapon poison." or entry.label..": "..(entry.seconds and ("base reference "..entry.seconds.." seconds; extensions follow the live endpoint. ") or "percentage reference uses the longest remaining time observed. ").."New binding: compare with the HUD before relying on it."}
end
D.entries.TARGET_VULNERABILITY={description="Vulnerability reminder: alerts when missing on your current NPC target for 2 seconds. Reads target status, not remaining time. Target binding needs live testing."}
D.entries.TARGET_SMOKE_CLOUD={description="Smoke Cloud reminder: alerts when missing on your current NPC target for 2 seconds. Reads target status, not remaining time. Target binding needs live testing."}
function D.describe(key,identifier)
 local names=require("src/timers").names
 local name=key=="buff" and identifier or names[key] and names[key][1]
 local entry=D.entries[name]
 return entry and entry.description or "Choose an effect. Duration is automatic; no full-duration entry is needed."
end
function D.maximum(state,remaining,base,identity)
 if state.durationIdentity~=identity or (remaining>0 and state.durationExpired) then
  state.maximum=nil;state.durationIdentity=identity
 end
 if remaining>0 then
  state.maximum=math.max(state.maximum or 0,base or 0,remaining)
  state.durationExpired=false
 else state.durationExpired=true end
 return state.maximum or base
end
function D.reset(state)
 state.maximum=nil;state.durationIdentity=nil;state.durationExpired=nil
end
return D
