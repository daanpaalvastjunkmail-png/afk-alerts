# Effect coverage — AFK ALERTS 0.6.31

The shared Add alert catalogue represents **275 own-effect timer bindings and 2 NPC-target presence reminders**. Of the timer bindings, 264 are newly connected and still require native HUD validation. This is coverage of named endpoints in the owner-provided beta export, not a claim that every game buff, debuff, item or status is exposed or verified.

In 0.6.32, these effects appear directly alongside ordinary alerts in Add alert, with categories and a searchable selector. Build 0.6.33 adds a visible search field; category/search changes select the first matching alert. Six generic family variants are represented by their existing Overload/Antifire/Aggression/Familiar choices instead of duplicate rows, for **284 user-facing choices** in total. Older saved single-timer bindings remain unchanged; the selector identifies those as saved timers when necessary.

## What was added

- Penance and Vampyrism **aspects**, separate from powder of penance. Old aura descriptions are not applied to these newer endpoints.
- All **18** exported incense endpoints: Guam, Tarromin, Marrentill, Harralander, Ranarr, Toadflax, Spirit weed, Irit, Wergali, Avantoe, Kwuarm, Bloodweed, Snapdragon, Cadantine, Lantadyme, Dwarf weed, Torstol and Fellstalk.
- Powder of penance and the other five colour-named scarab-powder endpoints. The latter retain explicit unidentified labels; their item-name mapping is not guessed.
- Shared scrimshaw and scripture/god-book/grimoire charge timers, blood essence, and exported Jas/Bik/Ful/Amascut proc effects. Shared charge endpoints do not identify the equipped item, distinguish every scripture, or guarantee whether a stopped timer means empty versus deactivated.
- Juju/perfect juju, Perfect Plus, selected extreme potions, bonfire, powerburst effects, archaeology consumables, defensive effects, conjures, other own-effect endpoints and own debuffs.
- Categories and text search. The current selection stays visible while filtering. Each entry retains its named identifier in saved/shared presets.

## Aspect replacement (0.6.40)

Penance's live timer is now confirmed by the owner. The replacement fix groups Animate Dead, Darkness, Penance, Vampyrism and Temporal Anomaly as mutually exclusive aspects, as described in [Jagex's Aura Overhaul notes](https://secure.runescape.com/m=news/patch-notes-aura-overhaul). A newly observed positive endpoint replaces the previous aspect, even if its old timestamp remains populated. Replacement resets that alert and clears its popup rather than firing a false expiry. Powder of penance remains independent. Stacked timers are not compared by longest remaining time; ambiguous startup values wait for a new observed activation. Transient missing data does not revive a cancelled aspect. New replacement behaviour is regression-tested and still needs a native switch check.

## NPC target reminders

Vulnerability and Smoke Cloud are **missing-status reminders**, not 60/120-second simulated timers. Their gameplay durations alone cannot establish whether a cast landed, was refreshed, was applied by another player or is active on a new target.

The supplied VarPlayer export provides:

| Reminder | Named flag | Parent variable | Exported mask |
| --- | --- | --- | --- |
| Vulnerability | `COMBATV2_TARGET_SIDE_PANEL_TARGET_VULNERABILITY` | `COMBATV2_TARGET_EFFECTS` (896) | `0x20000000` |
| Smoke Cloud | `COMBATV2_TARGET_SIDE_PANEL_TARGET_MAGIC_SMOKE_CLOUD` | `COMBATV2_TARGET_EFFECTS_8` (9418) | `0x80` |

The reader requires a current NPC target (`NPCTARGET`), excludes player targets, and waits for two seconds of known absence before alerting. No target, missing data, logout, target changes and a backwards clock clear the absence tracking. An observed active flag resets the alert. The packed-variable fallback uses the exported mask only when the named decoded flag is unavailable. This mapping still needs testing against the visible target bar in the native client.

## Time and percentage semantics

Timers use the existing 50 Hz client-Logic endpoint interpretation. This clock relationship was checked against overload snapshots; it remains an inference for new endpoint families until compared with their HUD values. Missing endpoints return unavailable and never invent a full duration or expire an unseen effect.

Penance/Vampyrism start with a 720-second percentage reference, incense with 600, and powder of penance with 1,800. Longer live remainders expand those references. All other new bindings use the longest observed remainder because their endpoint may be shared, stackable or have no researched universal base. Absolute seconds-remaining thresholds are independent of that percentage-reference uncertainty.

Ordinary ability cooldowns, enemy mechanic timers and future-mechanic predictions are excluded. Statuses without a named endpoint, binary-only effects, unexported pocket charge sources and effect-specific stack counts are not thereby implemented. Familiar data still requires separate native validation.

## Reproduce the generated catalogue

`python3 tools/build_effect_catalog.py /path/to/VarClient_index.json`

This uses the owner-provided export index, not wiki scraping or an in-game network request. `src/effect_catalog.lua` records explicit labels/categories and new-binding status. Research describes gameplay meaning; the export establishes names and target masks, not live units.

## Research

- [Jagex staff announcement: aspect multicasting](https://www.reddit.com/r/runescape/comments/1snv4ap/aspects_solomons_store_news_update_2/) — 12-minute casts and extension.
- [PvM Encyclopedia: consumables](https://pvme.io/pvme-guides/upgrading-info/consumables/) — incense and powder stacking, pocket items.
- [RuneScape Wiki: prayer powders](https://runescape.wiki/w/Template:Prayer_powder_details) — powder of penance item identity.
- [RuneScape Wiki: status-effect categories](https://runescape.wiki/w/Template:Buff_table/doc) — broader effect taxonomy, including effects without timers.

## Selectable catalogue

| Category | Effect | Binding | Validation |
| --- | --- | --- | --- |
| Aspects | Animate Dead | `COMBATV2_MAGIC_ANIMATE_DEAD_END_EFFECT_CLIENT` | Existing binding |
| Aspects | Darkness | `COMBATV2_BUFF_NECROMANCY_DARKNESS_END_CLIENT` | Existing binding |
| Aspects | Penance (aspect) | `COMBATV2_BUFF_PENANCE_END_CLIENT` | New binding; HUD validation needed |
| Aspects | Vampyrism (aspect) | `COMBATV2_BUFF_VAMPYRISM_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Attack Blood Tendrils | `COMBATV2_COOLDOWN_ATTACK_BLOOD_TENDRILS_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Combat effects | Barbassault Insignia Attack | `COMBATV2_COOLDOWN_BARBASSAULT_INSIGNIA_ATTACK_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Combat effects | Constitution 6Awe2 Blessing | `COMBATV2_COOLDOWN_CONSTITUTION_6AWE2_BLESSING_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Combat effects | Constitution Guthix Blessing | `COMBATV2_COOLDOWN_CONSTITUTION_GUTHIX_BLESSING_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Combat effects | Constitution Ice Asylum | `COMBATV2_COOLDOWN_CONSTITUTION_ICE_ASYLUM_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Combat effects | Constitution Reprisal | `COMBATV2_COOLDOWN_CONSTITUTION_REPRISAL_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Combat effects | Constitution Sacrifice | `COMBATV2_COOLDOWN_CONSTITUTION_SACRIFICE_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Combat effects | Constitution Transfigure | `COMBATV2_COOLDOWN_CONSTITUTION_TRANSFIGURE_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Combat effects | Lunar Magic Imbue Buff | `COMBATV2_LUNAR_MAGIC_IMBUE_BUFF_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Magic Asphyxiate Critical Damage | `COMBATV2_BUFF_MAGIC_ASPHYXIATE_CRITICAL_DAMAGE_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Magic Critical Strike Adrenaline Effect | `COMBATV2_BUFF_MAGIC_CRITICAL_STRIKE_ADRENALINE_EFFECT_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Magic Devourer T95 Passive | `COMBATV2_BUFF_MAGIC_DEVOURER_T95_PASSIVE_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Magic Devourer T95 Passive Adrenaline Gain | `COMBATV2_BUFF_MAGIC_DEVOURER_T95_PASSIVE_ADRENALINE_GAIN_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Magic Greater Sonic Wave | `COMBATV2_MAGIC_GREATER_SONIC_WAVE_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Combat effects | Magic Metamorphosis | `COMBATV2_COOLDOWN_MAGIC_METAMORPHOSIS_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Combat effects | Magic Paradox | `COMBATV2_BUFF_MAGIC_PARADOX_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Magic Smoke Tendrils | `COMBATV2_COOLDOWN_MAGIC_SMOKE_TENDRILS_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Combat effects | Magic Sunshine | `COMBATV2_COOLDOWN_MAGIC_SUNSHINE_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Combat effects | Magic Temporal Anomaly | `COMBATV2_BUFF_MAGIC_TEMPORAL_ANOMALY_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Magic Wild Magic Infused | `COMBATV2_BUFF_MAGIC_WILD_MAGIC_INFUSED_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Magic Wrack | `COMBATV2_BUFF_MAGIC_WRACK_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Necromancy Death Essence | `COMBATV2_BUFF_NECROMANCY_DEATH_ESSENCE_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Necromancy Invoke Death | `COMBATV2_BUFF_NECROMANCY_INVOKE_DEATH_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Necromancy Invoke Lord Of Bones | `COMBATV2_BUFF_NECROMANCY_INVOKE_LORD_OF_BONES_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Necromancy Residual Soul | `COMBATV2_BUFF_NECROMANCY_RESIDUAL_SOUL_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Necromancy Soul Crush | `COMBATV2_BUFF_NECROMANCY_SOUL_CRUSH_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Necromancy Spectral Scythe | `COMBATV2_BUFF_NECROMANCY_SPECTRAL_SCYTHE_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Necromancy Spirit Phantom Guardian | `COMBATV2_BUFF_NECROMANCY_SPIRIT_PHANTOM_GUARDIAN_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Necromancy Spirit Putrid Zombie | `COMBATV2_BUFF_NECROMANCY_SPIRIT_PUTRID_ZOMBIE_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Necromancy Spirit Skeleton Warrior | `COMBATV2_BUFF_NECROMANCY_SPIRIT_SKELETON_WARRIOR_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Necromancy Spirit Vengeful Ghost | `COMBATV2_BUFF_NECROMANCY_SPIRIT_VENGEFUL_GHOST_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Necromancy Split Soul | `COMBATV2_BUFF_NECROMANCY_SPLIT_SOUL_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Necromancy Threads Of Fate | `COMBATV2_BUFF_NECROMANCY_THREADS_OF_FATE_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Necromancy Undead Instinct | `COMBATV2_BUFF_NECROMANCY_UNDEAD_INSTINCT_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Penance Attack | `COMBATV2_PENANCE_ATTACK_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Combat effects | Ranged Critical Strike Adrenaline Effect | `COMBATV2_BUFF_RANGED_CRITICAL_STRIKE_ADRENALINE_EFFECT_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Ranged Deaths Swiftness | `COMBATV2_COOLDOWN_RANGED_DEATHS_SWIFTNESS_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Combat effects | Ranged Imbued Shadows | `COMBATV2_BUFF_RANGED_IMBUED_SHADOWS_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Ranged Searing Winds | `COMBATV2_BUFF_RANGED_SEARING_WINDS_END_CLIENT` | New binding; HUD validation needed |
| Combat effects | Ranged Shadow Tendrils | `COMBATV2_COOLDOWN_RANGED_SHADOW_TENDRILS_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Combat effects | Strength Chaos Roar | `COMBATV2_COOLDOWN_STRENGTH_CHAOS_ROAR_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Combat effects | Strength Pulverise | `COMBATV2_COOLDOWN_STRENGTH_PULVERISE_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Core timers | Aggression potion | `COMBATV2_COOLDOWN_WILDERNESS_AGGRESSION_POTION_END_EFFECT_CLIENT` | Existing binding |
| Core timers | Antifire | `COMBATV2_COOLDOWN_DRAGONFIRE_END_EFFECT_CLIENT` | Existing binding |
| Core timers | Dungeoneering overload | `COMBATV2_COOLDOWN_RAND_OVERLOAD_END_EFFECT_CLIENT` | Existing binding |
| Core timers | Familiar duration | `COMBATV2_COOLDOWN_FAMILIAR_TIMER_END_EFFECT_CLIENT` | Existing binding |
| Core timers | Overload | `COMBATV2_COOLDOWN_OVERLOAD_END_EFFECT_CLIENT` | Existing binding |
| Core timers | Prayer renewal | `COMBATV2_COOLDOWN_PRAYER_RENEWAL_END_EFFECT_CLIENT` | Existing binding |
| Core timers | Summoning renewal | `COMBATV2_COOLDOWN_LORE_RENEWAL_END_EFFECT_CLIENT` | Existing binding |
| Core timers | Super antifire | `COMBATV2_COOLDOWN_SUPER_DRAGONFIRE_END_EFFECT_CLIENT` | Existing binding |
| Core timers | Weapon poison | `COMBATV2_COOLDOWN_WEAPON_POISON_END_EFFECT_CLIENT` | Existing binding |
| Debuffs on you | Bind | `COMBATV2_COOLDOWN_BIND_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Debuffs on you | Bleed | `COMBATV2_COOLDOWN_BLEED_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Debuffs on you | Dsf Jellyfish Stun | `COMBATV2_DSF_JELLYFISH_STUN_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Debuffs on you | League Relic Buff Combat Resurrection Cooldown | `COMBATV2_DEBUFF_LEAGUE_RELIC_BUFF_COMBAT_RESURRECTION_COOLDOWN_END_CLIENT` | New binding; HUD validation needed |
| Debuffs on you | League Relic Buff Free Special Attack Cooldown | `COMBATV2_DEBUFF_LEAGUE_RELIC_BUFF_FREE_SPECIAL_ATTACK_COOLDOWN_END_CLIENT` | New binding; HUD validation needed |
| Debuffs on you | League Relic Debuff Sliver Of Edicts Cooldown | `COMBATV2_DEBUFF_LEAGUE_RELIC_DEBUFF_SLIVER_OF_EDICTS_COOLDOWN_END_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Poison-related timer (disabled) | `COMBATV2_COOLDOWN_POISON_END_EFFECT_CLIENT` | Disabled: also reacts to weapon poison; cannot identify player poisoning |
| Debuffs on you | Pulverised | `COMBATV2_DEBUFF_PULVERISED_END_CLIENT` | New binding; HUD validation needed |
| Debuffs on you | Resurrection Sickness | `COMBATV2_DEBUFF_RESURRECTION_SICKNESS_END_CLIENT` | New binding; HUD validation needed |
| Debuffs on you | Severed | `COMBATV2_DEBUFF_SEVERED_END_CLIENT` | New binding; HUD validation needed |
| Debuffs on you | Stun | `COMBATV2_COOLDOWN_STUN_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Defensive effects | Defence Anticipation | `COMBATV2_COOLDOWN_DEFENCE_ANTICIPATION_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Defensive effects | Defence Barricade | `COMBATV2_COOLDOWN_DEFENCE_BARRICADE_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Defensive effects | Defence Devotion | `COMBATV2_COOLDOWN_DEFENCE_DEVOTION_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Defensive effects | Defence Divert | `COMBATV2_COOLDOWN_DEFENCE_DIVERT_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Defensive effects | Defence Freedom | `COMBATV2_COOLDOWN_DEFENCE_FREEDOM_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Defensive effects | Defence Heroism | `COMBATV2_COOLDOWN_DEFENCE_HEROISM_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Defensive effects | Defence Natural Instinct | `COMBATV2_COOLDOWN_DEFENCE_NATURAL_INSTINCT_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Defensive effects | Defence Preparation | `COMBATV2_COOLDOWN_DEFENCE_PREPARATION_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Defensive effects | Defence Reflect | `COMBATV2_COOLDOWN_DEFENCE_REFLECT_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Defensive effects | Defence Rejuvinate | `COMBATV2_COOLDOWN_DEFENCE_REJUVINATE_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Defensive effects | Defence Resonance | `COMBATV2_COOLDOWN_DEFENCE_RESONANCE_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Defensive effects | Defence Revenge | `COMBATV2_COOLDOWN_DEFENCE_REVENGE_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Defensive effects | Defence Stop Attacking | `COMBATV2_COOLDOWN_DEFENCE_STOP_ATTACKING_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Incense sticks | Avantoe incense sticks | `COMBATV2_INCENSE_BURNER_AVANTOE_END_CLIENT` | New binding; HUD validation needed |
| Incense sticks | Bloodweed incense sticks | `COMBATV2_INCENSE_BURNER_BLOODWEED_END_CLIENT` | New binding; HUD validation needed |
| Incense sticks | Cadantine incense sticks | `COMBATV2_INCENSE_BURNER_CADANTINE_END_CLIENT` | New binding; HUD validation needed |
| Incense sticks | Dwarf weed incense sticks | `COMBATV2_INCENSE_BURNER_DWARF_END_CLIENT` | New binding; HUD validation needed |
| Incense sticks | Fellstalk incense sticks | `COMBATV2_INCENSE_BURNER_FELLSTALK_END_CLIENT` | New binding; HUD validation needed |
| Incense sticks | Guam incense sticks | `COMBATV2_INCENSE_BURNER_GUAM_END_CLIENT` | New binding; HUD validation needed |
| Incense sticks | Harralander incense sticks | `COMBATV2_INCENSE_BURNER_HARRALANDER_END_CLIENT` | New binding; HUD validation needed |
| Incense sticks | Irit incense sticks | `COMBATV2_INCENSE_BURNER_IRIT_END_CLIENT` | New binding; HUD validation needed |
| Incense sticks | Kwuarm incense sticks | `COMBATV2_INCENSE_BURNER_KWUARM_END_CLIENT` | New binding; HUD validation needed |
| Incense sticks | Lantadyme incense sticks | `COMBATV2_INCENSE_BURNER_LANTADYME_END_CLIENT` | New binding; HUD validation needed |
| Incense sticks | Marrentill incense sticks | `COMBATV2_INCENSE_BURNER_MARRENTILL_END_CLIENT` | New binding; HUD validation needed |
| Incense sticks | Ranarr incense sticks | `COMBATV2_INCENSE_BURNER_RANARR_END_CLIENT` | New binding; HUD validation needed |
| Incense sticks | Snapdragon incense sticks | `COMBATV2_INCENSE_BURNER_SNAPDRAGON_END_CLIENT` | New binding; HUD validation needed |
| Incense sticks | Spirit weed incense sticks | `COMBATV2_INCENSE_BURNER_SPIRIT_END_CLIENT` | New binding; HUD validation needed |
| Incense sticks | Tarromin incense sticks | `COMBATV2_INCENSE_BURNER_TARROMIN_END_CLIENT` | New binding; HUD validation needed |
| Incense sticks | Toadflax incense sticks | `COMBATV2_INCENSE_BURNER_TOADFLAX_END_CLIENT` | New binding; HUD validation needed |
| Incense sticks | Torstol incense sticks | `COMBATV2_INCENSE_BURNER_TORSTOL_END_CLIENT` | New binding; HUD validation needed |
| Incense sticks | Wergali incense sticks | `COMBATV2_INCENSE_BURNER_WERGALI_END_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Adrenaline Buff | `ADRENALINE_BUFF_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Baron Shark | `COMBATV2_COOLDOWN_BARON_SHARK_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Beach Cocktail Artisan | `COMBATV2_BEACH_COCKTAIL_ARTISAN_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Beach Cocktail Combat | `COMBATV2_BEACH_COCKTAIL_COMBAT_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Beach Cocktail Gathering | `COMBATV2_BEACH_COCKTAIL_GATHERING_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Beach Cocktail Support | `COMBATV2_BEACH_COCKTAIL_SUPPORT_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Beach Dungeoneering | `COMBATV2_BEACH_DUNGEONEERING_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Beach Fishing | `COMBATV2_BEACH_FISHING_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Beach Hook A Duck | `COMBATV2_BEACH_HOOK_A_DUCK_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Beach Palm Trees | `COMBATV2_BEACH_PALM_TREES_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Beach Sandcastles | `COMBATV2_BEACH_SANDCASTLES_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Blood Tithe | `COMBATV2_BUFF_BLOOD_TITHE_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Blood Tithe Combust | `COMBATV2_BUFF_BLOOD_TITHE_COMBUST_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Bonfire | `COMBATV2_COOLDOWN_BONFIRE_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Bslay Ascendri Bolts | `COMBATV2_COOLDOWN_BSLAY_ASCENDRI_BOLTS_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Channelling | `COMBATV2_COOLDOWN_CHANNELLING_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Chronicle Card | `COMBATV2_COOLDOWN_CHRONICLE_CARD_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Conch | `COMBATV2_COOLDOWN_CONCH_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Crystal Shield Absorb | `COMBATV2_COOLDOWN_CRYSTAL_SHIELD_ABSORB_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Crystal Shield Defend | `COMBATV2_COOLDOWN_CRYSTAL_SHIELD_DEFEND_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Divchamber Boost | `COMBATV2_DIVCHAMBER_BOOST_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Dracolich Set Effect | `COMBATV2_BUFF_DRACOLICH_SET_EFFECT_END_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Dragon Battleaxe Effect | `COMBATV2_BUFF_DRAGON_BATTLEAXE_EFFECT_END_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Dragon Scimitar Effect | `COMBATV2_BUFF_DRAGON_SCIMITAR_EFFECT_END_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Dsf Reward Boost 1 | `COMBATV2_DSF_REWARD_BOOST_1_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Dsf Reward Boost 2 | `COMBATV2_DSF_REWARD_BOOST_2_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Dsf Reward Boost 3 | `COMBATV2_DSF_REWARD_BOOST_3_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Dungeon Ulthven Demon Slayer | `COMBATV2_DUNGEON_ULTHVEN_DEMON_SLAYER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Dungeon Ulthven Dragon Slayer | `COMBATV2_DUNGEON_ULTHVEN_DRAGON_SLAYER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Dungeon Ulthven Undead Slayer | `COMBATV2_DUNGEON_ULTHVEN_UNDEAD_SLAYER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Elr1 Spirit Charm | `COMBATV2_COOLDOWN_ELR1_SPIRIT_CHARM_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Event Crafting Fish Flinger Enhancer | `COMBATV2_EVENT_CRAFTING_FISH_FLINGER_ENHANCER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Event Crafting Fishing Item Xp Enhancer | `COMBATV2_EVENT_CRAFTING_FISHING_ITEM_XP_ENHANCER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Event Crafting Fishing Perk Enhancer | `COMBATV2_EVENT_CRAFTING_FISHING_PERK_ENHANCER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Event Crafting Fletching Make X Max Enhancer | `COMBATV2_EVENT_CRAFTING_FLETCHING_MAKE_X_MAX_ENHANCER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Event Crafting Fletching Make X Max Large Enhancer | `COMBATV2_EVENT_CRAFTING_FLETCHING_MAKE_X_MAX_LARGE_ENHANCER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Event Crafting Fletching Resource Enhancer | `COMBATV2_EVENT_CRAFTING_FLETCHING_RESOURCE_ENHANCER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Event Crafting Mining Crit Enhancer | `COMBATV2_EVENT_CRAFTING_MINING_CRIT_ENHANCER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Event Crafting Mining Geode Enhancer | `COMBATV2_EVENT_CRAFTING_MINING_GEODE_ENHANCER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Event Crafting Smithing Luminite Enhancer | `COMBATV2_EVENT_CRAFTING_SMITHING_LUMINITE_ENHANCER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Event Crafting Smithing Respect Enhancer | `COMBATV2_EVENT_CRAFTING_SMITHING_RESPECT_ENHANCER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Event16 Area Boost | `COMBATV2_EVENT16_AREA_BOOST_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Event16 Boost Juice Duration | `COMBATV2_EVENT16_BOOST_JUICE_DURATION_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Event16 Passive Boost | `COMBATV2_EVENT16_PASSIVE_BOOST_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Extreme Cooking | `COMBATV2_COOLDOWN_EXTREME_COOKING_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Extreme Divination | `COMBATV2_COOLDOWN_EXTREME_DIVINATION_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Extreme Hunting | `COMBATV2_COOLDOWN_EXTREME_HUNTING_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Extreme Invention | `COMBATV2_COOLDOWN_EXTREME_INVENTION_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Extreme Runecrafting | `COMBATV2_COOLDOWN_EXTREME_RUNECRAFTING_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Extreme Thieving | `COMBATV2_COOLDOWN_EXTREME_THIEVING_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Familiarisation | `COMBATV2_COOLDOWN_FAMILIARISATION_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Farm Req Brassica Primer | `COMBATV2_FARM_REQ_BRASSICA_PRIMER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Frostblades | `COMBATV2_BUFF_FROSTBLADES_END_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Glacial Embrace | `COMBATV2_BUFF_GLACIAL_EMBRACE_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Great Gunkan | `COMBATV2_COOLDOWN_GREAT_GUNKAN_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Great Maki | `COMBATV2_COOLDOWN_GREAT_MAKI_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Halloween Bite | `COMBATV2_COOLDOWN_HALLOWEEN_BITE_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Halloween23 Candy Enhancer Divination | `COMBATV2_HALLOWEEN23_CANDY_ENHANCER_DIVINATION_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Halloween23 Candy Enhancer Firemaking | `COMBATV2_HALLOWEEN23_CANDY_ENHANCER_FIREMAKING_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Halloween23 Candy Enhancer Luck | `COMBATV2_HALLOWEEN23_CANDY_ENHANCER_LUCK_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Halloween23 Candy Enhancer Prayer | `COMBATV2_HALLOWEEN23_CANDY_ENHANCER_PRAYER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Halloween23 Candy Enhancer Slayer | `COMBATV2_HALLOWEEN23_CANDY_ENHANCER_SLAYER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | House Ring High | `COMBATV2_COOLDOWN_HOUSE_RING_HIGH_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Idols Buff 1 | `COMBATV2_IDOLS_BUFF_1_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Idols Buff 2 | `COMBATV2_IDOLS_BUFF_2_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Idols Buff 3 | `COMBATV2_IDOLS_BUFF_3_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Idols Buff 4 | `COMBATV2_IDOLS_BUFF_4_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Idols Buff 5 | `COMBATV2_IDOLS_BUFF_5_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Ingenuity Of The Humans | `COMBATV2_INGENUITY_OF_THE_HUMANS_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Invent Perk Equilibrium | `COMBATV2_COOLDOWN_INVENT_PERK_EQUILIBRIUM_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Invent Perk Relentless | `COMBATV2_COOLDOWN_INVENT_PERK_RELENTLESS_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | League Relic Buff Sliver Of Edicts Cooldown | `COMBATV2_BUFF_LEAGUE_RELIC_BUFF_SLIVER_OF_EDICTS_COOLDOWN_END_CLIENT` | New binding; HUD validation needed |
| Other exported effects | League Relic Buff Stone Of Jas Boost | `COMBATV2_BUFF_LEAGUE_RELIC_BUFF_STONE_OF_JAS_BOOST_END_CLIENT` | New binding; HUD validation needed |
| Other exported effects | League Relic Combat Avernic Rampage Cooldown | `COMBATV2_BUFF_LEAGUE_RELIC_COMBAT_AVERNIC_RAMPAGE_COOLDOWN_END_CLIENT` | New binding; HUD validation needed |
| Other exported effects | League Relic Combat Light Strike Cooldown | `COMBATV2_BUFF_LEAGUE_RELIC_COMBAT_LIGHT_STRIKE_COOLDOWN_END_CLIENT` | New binding; HUD validation needed |
| Other exported effects | League Relic Combat Lord Of Light Cooldown | `COMBATV2_BUFF_LEAGUE_RELIC_COMBAT_LORD_OF_LIGHT_COOLDOWN_END_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Lore Ancient Kalgerion Demon Scroll | `COMBATV2_LORE_ANCIENT_KALGERION_DEMON_SCROLL_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Lore Enlightenment | `COMBATV2_COOLDOWN_LORE_ENLIGHTENMENT_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Lunar Tune Bane Ore Buff | `COMBATV2_LUNAR_TUNE_BANE_ORE_BUFF_END_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Melee Berserk | `COMBATV2_BUFF_MELEE_BERSERK_END_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Melee Channel To Dot Buff | `COMBATV2_MELEE_CHANNEL_TO_DOT_BUFF_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Melee Dismember | `COMBATV2_BUFF_MELEE_DISMEMBER_END_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Melee Greater Fury Guaranteed Critical Strike | `COMBATV2_BUFF_MELEE_GREATER_FURY_GUARANTEED_CRITICAL_STRIKE_END_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Melee Meteor Strike Adrenaline Effect | `COMBATV2_BUFF_MELEE_METEOR_STRIKE_ADRENALINE_EFFECT_END_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Melee Sunfall Slam | `COMBATV2_BUFF_MELEE_SUNFALL_SLAM_END_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Menaphos Golden Touch | `COMBATV2_MENAPHOS_GOLDEN_TOUCH_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Menaphos Limitless | `COMBATV2_MENAPHOS_LIMITLESS_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Menaphos Unsullied | `COMBATV2_MENAPHOS_UNSULLIED_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Mhaw May21 Stone | `COMBATV2_COOLDOWN_MHAW_MAY21_STONE_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Mtx Trader Duration | `COMBATV2_MTX_TRADER_DURATION_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Mtx Xp Bomb | `COMBATV2_MTX_XP_BOMB_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Mtxbeach15 Cocktail | `COMBATV2_COOLDOWN_MTXBEACH15_COCKTAIL_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Powerburst | `COMBATV2_COOLDOWN_POWERBURST_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Prayer Eclipsed Soul Effect | `COMBATV2_BUFF_PRAYER_ECLIPSED_SOUL_EFFECT_END_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Primordial Ice | `COMBATV2_BUFF_PRIMORDIAL_ICE_END_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Protean Extender | `COMBATV2_COOLDOWN_PROTEAN_EXTENDER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Protean Powerup | `COMBATV2_COOLDOWN_PROTEAN_POWERUP_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Resurrection Damage Immunity | `COMBATV2_BUFF_RESURRECTION_DAMAGE_IMMUNITY_END_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Seren Crystal Mask | `COMBATV2_COOLDOWN_SEREN_CRYSTAL_MASK_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Soulfire Combust | `COMBATV2_BUFF_SOULFIRE_COMBUST_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Spirit Attraction | `COMBATV2_SPIRIT_ATTRACTION_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Staff Of Darkness | `COMBATV2_COOLDOWN_STAFF_OF_DARKNESS_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Staff Of Light | `COMBATV2_COOLDOWN_STAFF_OF_LIGHT_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Trh165 Cinder Core | `COMBATV2_COOLDOWN_TRH165_CINDER_CORE_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Trh177 Valentines Coin | `COMBATV2_COOLDOWN_TRH177_VALENTINES_COIN_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Trh205 Love Letter Bxp Boost | `COMBATV2_COOLDOWN_TRH205_LOVE_LETTER_BXP_BOOST_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Trh205 Love Letter Xp Boost | `COMBATV2_COOLDOWN_TRH205_LOVE_LETTER_XP_BOOST_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Trh50 Pulse Essence | `COMBATV2_COOLDOWN_TRH50_PULSE_ESSENCE_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Trh78 Lucky Clover | `COMBATV2_COOLDOWN_TRH78_LUCKY_CLOVER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Trh82 Valentines Staff | `COMBATV2_COOLDOWN_TRH82_VALENTINES_STAFF_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | White Firelighter Buff | `COMBATV2_WHITE_FIRELIGHTER_BUFF_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Wilder Pie | `COMBATV2_COOLDOWN_WILDER_PIE_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Woodcutting Buff Weak Side Chop | `WOODCUTTING_BUFF_WEAK_SIDE_CHOP_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Other exported effects | Zaros Spec | `COMBATV2_COOLDOWN_ZAROS_SPEC_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Pocket items | Blood essence timer | `COMBATV2_COOLDOWN_BLOOD_ESSENCE_TIMER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Pocket items | Reflecting blood essence effect | `COMBATV2_COOLDOWN_BLOOD_ESSENCE_REFLECT_TIMER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Pocket items | Scrimshaw charge timer (shared) | `COMBATV2_COOLDOWN_SCRIMSHAW_TIMER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Pocket items | Scripture / god book / grimoire charge timer (shared) | `COMBATV2_COOLDOWN_GOD_BOOK_TIMER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Pocket items | Scripture of Amascut damage-over-time effect | `COMBATV2_BUFF_RAID_REBIRTH1_AMASCUT_BOOK_DOT_EFFECT_END_CLIENT` | New binding; HUD validation needed |
| Pocket items | Scripture of Amascut proc | `COMBATV2_BUFF_RAID_REBIRTH1_AMASCUT_BOOK_END_CLIENT` | New binding; HUD validation needed |
| Pocket items | Scripture of Bik proc | `COMBATV2_EGWD_BIK_GOD_BOOK_EFFECT_END_CLIENT` | New binding; HUD validation needed |
| Pocket items | Scripture of Ful proc | `COMBATV2_EGWD_FUL_GOD_BOOK_EFFECT_END_CLIENT` | New binding; HUD validation needed |
| Pocket items | Scripture of Jas proc | `COMBATV2_EGWD_JAS_GOD_BOOK_EFFECT_END_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Adrenaline Potion | `COMBATV2_COOLDOWN_ADRENALINE_POTION_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Agility Potion | `COMBATV2_COOLDOWN_AGILITY_POTION_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Arch Consumable Excavation Xp | `COMBATV2_ARCH_CONSUMABLE_EXCAVATION_XP_END_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Arch Consumable Material Chance | `COMBATV2_ARCH_CONSUMABLE_MATERIAL_CHANCE_END_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Arch Consumable Mattock Precision | `COMBATV2_ARCH_CONSUMABLE_MATTOCK_PRECISION_END_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Arch Consumable Soil Chance | `COMBATV2_ARCH_CONSUMABLE_SOIL_CHANCE_END_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Crafting Potion | `COMBATV2_COOLDOWN_CRAFTING_POTION_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Event Crafting Woodcutting Item Xp Enhancer | `COMBATV2_EVENT_CRAFTING_WOODCUTTING_ITEM_XP_ENHANCER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Event Crafting Woodcutting Perk Enhancer | `COMBATV2_EVENT_CRAFTING_WOODCUTTING_PERK_ENHANCER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Halloween23 Candy Enhancer Arch | `COMBATV2_HALLOWEEN23_CANDY_ENHANCER_ARCH_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Herb120 Charming Potion | `HERB120_CHARMING_POTION_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Herb120 Harvest Potion | `HERB120_HARVEST_POTION_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Juju Farming | `COMBATV2_COOLDOWN_JUJU_FARMING_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Juju Fishing | `COMBATV2_COOLDOWN_JUJU_FISHING_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Juju Guthix | `COMBATV2_COOLDOWN_JUJU_GUTHIX_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Juju Hunter | `COMBATV2_COOLDOWN_JUJU_HUNTER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Juju Mining | `COMBATV2_COOLDOWN_JUJU_MINING_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Juju Saradomin | `COMBATV2_COOLDOWN_JUJU_SARADOMIN_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Juju Scentless | `COMBATV2_COOLDOWN_JUJU_SCENTLESS_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Juju Woodcutting | `COMBATV2_COOLDOWN_JUJU_WOODCUTTING_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Juju Zamorak | `COMBATV2_COOLDOWN_JUJU_ZAMORAK_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Perfect Juju Agility | `COMBATV2_COOLDOWN_PERFECT_JUJU_AGILITY_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Perfect Juju Dungeoneering | `COMBATV2_COOLDOWN_PERFECT_JUJU_DUNGEONEERING_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Perfect Juju Farming | `COMBATV2_COOLDOWN_PERFECT_JUJU_FARMING_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Perfect Juju Fishing | `COMBATV2_COOLDOWN_PERFECT_JUJU_FISHING_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Perfect Juju Herblore | `COMBATV2_COOLDOWN_PERFECT_JUJU_HERBLORE_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Perfect Juju Mining | `COMBATV2_COOLDOWN_PERFECT_JUJU_MINING_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Perfect Juju Prayer | `COMBATV2_COOLDOWN_PERFECT_JUJU_PRAYER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Perfect Juju Smithing | `COMBATV2_COOLDOWN_PERFECT_JUJU_SMITHING_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Perfect Juju Woodcutting | `COMBATV2_COOLDOWN_PERFECT_JUJU_WOODCUTTING_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Perfect Plus | `COMBATV2_COOLDOWN_PERFECT_PLUS_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Pow Double Lifepoints Buff | `POW_DOUBLE_LIFEPOINTS_BUFF_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Pow Movement Buff | `POW_MOVEMENT_BUFF_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Pow Opportunity Buff | `POW_OPPORTUNITY_BUFF_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Pow Rune Creation Buff | `POW_RUNE_CREATION_BUFF_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Pow Smithing Progress Buff | `POW_SMITHING_PROGRESS_BUFF_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Pow Special Moves Buff | `POW_SPECIAL_MOVES_BUFF_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Skilling Offhand Hunter | `COMBATV2_BUFF_SKILLING_OFFHAND_HUNTER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Super Mining Potion | `COMBATV2_COOLDOWN_SUPER_MINING_POTION_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Trh44 Valentines Love Potion | `COMBATV2_COOLDOWN_TRH44_VALENTINES_LOVE_POTION_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Trh44 Valentines Love Potion Other | `COMBATV2_COOLDOWN_TRH44_VALENTINES_LOVE_POTION_OTHER_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Trh94 Skilling Backpack | `COMBATV2_COOLDOWN_TRH94_SKILLING_BACKPACK_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Wilderness Camo Potion | `COMBATV2_COOLDOWN_WILDERNESS_CAMO_POTION_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Wilderness Luck Potion | `COMBATV2_COOLDOWN_WILDERNESS_LUCK_POTION_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Wilderness Luck Potion Enhanced | `COMBATV2_COOLDOWN_WILDERNESS_LUCK_POTION_ENHANCED_END_EFFECT_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Woodcutting Consumable Enchanted Nest Chance | `COMBATV2_WOODCUTTING_CONSUMABLE_ENCHANTED_NEST_CHANCE_END_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Woodcutting Consumable Log Xp | `COMBATV2_WOODCUTTING_CONSUMABLE_LOG_XP_END_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Woodcutting Consumable Nest Attuner | `COMBATV2_WOODCUTTING_CONSUMABLE_NEST_ATTUNER_END_CLIENT` | New binding; HUD validation needed |
| Potions & skilling | Woodcutting Consumable Perfect Cut Chance | `COMBATV2_WOODCUTTING_CONSUMABLE_PERFECT_CUT_CHANCE_END_CLIENT` | New binding; HUD validation needed |
| Prayer powders | Powder of penance | `COMBATV2_DUEL_ARENA_REMOVAL_SCARAB_POWDER_GOLDEN_END_CLIENT` | New binding; HUD validation needed |
| Prayer powders | Scarab powder: black (unidentified) | `COMBATV2_DUEL_ARENA_REMOVAL_SCARAB_POWDER_BLACK_END_CLIENT` | New binding; HUD validation needed |
| Prayer powders | Scarab powder: blue (unidentified) | `COMBATV2_DUEL_ARENA_REMOVAL_SCARAB_POWDER_BLUE_END_CLIENT` | New binding; HUD validation needed |
| Prayer powders | Scarab powder: green (unidentified) | `COMBATV2_DUEL_ARENA_REMOVAL_SCARAB_POWDER_GREEN_END_CLIENT` | New binding; HUD validation needed |
| Prayer powders | Scarab powder: purple (unidentified) | `COMBATV2_DUEL_ARENA_REMOVAL_SCARAB_POWDER_PURPLE_END_CLIENT` | New binding; HUD validation needed |
| Prayer powders | Scarab powder: red (unidentified) | `COMBATV2_DUEL_ARENA_REMOVAL_SCARAB_POWDER_RED_END_CLIENT` | New binding; HUD validation needed |
| Target debuffs | Smoke Cloud missing on NPC target | `TARGET_SMOKE_CLOUD` | NPC status flag; no countdown |
| Target debuffs | Vulnerability missing on NPC target | `TARGET_VULNERABILITY` | NPC status flag; no countdown |
