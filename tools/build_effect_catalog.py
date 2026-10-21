import json,re
from pathlib import Path
root=Path(__file__).resolve().parent.parent
import sys
index=Path(sys.argv[1]) if len(sys.argv)>1 else None
if index is None:raise SystemExit('Usage: python3 tools/build_effect_catalog.py VarClient_index.json')
old=['COMBATV2_COOLDOWN_OVERLOAD_END_EFFECT_CLIENT','COMBATV2_COOLDOWN_RAND_OVERLOAD_END_EFFECT_CLIENT','COMBATV2_COOLDOWN_DRAGONFIRE_END_EFFECT_CLIENT','COMBATV2_COOLDOWN_SUPER_DRAGONFIRE_END_EFFECT_CLIENT','COMBATV2_COOLDOWN_WILDERNESS_AGGRESSION_POTION_END_EFFECT_CLIENT','COMBATV2_COOLDOWN_FAMILIAR_TIMER_END_EFFECT_CLIENT','COMBATV2_COOLDOWN_PRAYER_RENEWAL_END_EFFECT_CLIENT','COMBATV2_COOLDOWN_LORE_RENEWAL_END_EFFECT_CLIENT','COMBATV2_MAGIC_ANIMATE_DEAD_END_EFFECT_CLIENT','COMBATV2_BUFF_NECROMANCY_DARKNESS_END_CLIENT','COMBATV2_COOLDOWN_WEAPON_POISON_END_EFFECT_CLIENT']
aliases={
 'COMBATV2_COOLDOWN_POISON_END_EFFECT_CLIENT':('Poison-related timer (disabled)','Other exported effects',None),
 'COMBATV2_BUFF_PENANCE_END_CLIENT':('Penance (aspect)','Aspects',720),
 'COMBATV2_BUFF_VAMPYRISM_END_CLIENT':('Vampyrism (aspect)','Aspects',720),
 'COMBATV2_COOLDOWN_SCRIMSHAW_TIMER_END_EFFECT_CLIENT':('Scrimshaw charge timer (shared)','Pocket items',None),
 'COMBATV2_COOLDOWN_GOD_BOOK_TIMER_END_EFFECT_CLIENT':('Scripture / god book / grimoire charge timer (shared)','Pocket items',None),
 'COMBATV2_DUEL_ARENA_REMOVAL_SCARAB_POWDER_GOLDEN_END_CLIENT':('Powder of penance','Prayer powders',1800),
 'COMBATV2_COOLDOWN_BLOOD_ESSENCE_TIMER_END_EFFECT_CLIENT':('Blood essence timer','Pocket items',None),
 'COMBATV2_COOLDOWN_BLOOD_ESSENCE_REFLECT_TIMER_END_EFFECT_CLIENT':('Reflecting blood essence effect','Pocket items',None),
 'COMBATV2_EGWD_JAS_GOD_BOOK_EFFECT_END_CLIENT':('Scripture of Jas proc','Pocket items',None),
 'COMBATV2_EGWD_BIK_GOD_BOOK_EFFECT_END_CLIENT':('Scripture of Bik proc','Pocket items',None),
 'COMBATV2_EGWD_FUL_GOD_BOOK_EFFECT_END_CLIENT':('Scripture of Ful proc','Pocket items',None),
 'COMBATV2_BUFF_RAID_REBIRTH1_AMASCUT_BOOK_END_CLIENT':('Scripture of Amascut proc','Pocket items',None),
 'COMBATV2_BUFF_RAID_REBIRTH1_AMASCUT_BOOK_DOT_EFFECT_END_CLIENT':('Scripture of Amascut damage-over-time effect','Pocket items',None),
}
rows=[]
for e in json.loads(index.read_text())['entries']:
 n=e['name']
 if n in old:continue
 # Effect endpoints only: ordinary ability cooldowns are deliberately excluded.
 take=n.endswith('_END_EFFECT_CLIENT') or (n.startswith(('COMBATV2_BUFF_','COMBATV2_DEBUFF_','COMBATV2_INCENSE_BURNER_','COMBATV2_DUEL_ARENA_REMOVAL_SCARAB_POWDER_','COMBATV2_ARCH_CONSUMABLE_','COMBATV2_WOODCUTTING_CONSUMABLE_','COMBATV2_LUNAR_')) and n.endswith('_END_CLIENT'))
 # Do not treat enemy encounter/mechanic timers as own-player buffs.
 if any(x in n for x in ['_BOSS_','_BOSS2_','_MOLE2_','_REXKINGS_','_EGWD_','_DOM_MINE_','_FIGHTKILN_']):take=False
 if n in aliases:take=True
 if not take or e['valueType']!='INTEGER':continue
 cat='Other exported effects';seconds=None
 label=n.removeprefix('COMBATV2_').removeprefix('COOLDOWN_').removeprefix('BUFF_').removeprefix('DEBUFF_')
 label=re.sub(r'_END(?:_EFFECT)?_CLIENT$','',label).replace('_',' ').title()
 if '_INCENSE_BURNER_' in n:
  herb=n.split('_BURNER_')[1].removesuffix('_END_CLIENT').title();herb={'Spirit':'Spirit weed','Dwarf':'Dwarf weed'}.get(herb,herb)
  label=herb+' incense sticks';cat='Incense sticks';seconds=600
 elif '_SCARAB_POWDER_' in n:label='Scarab powder: '+n.split('_POWDER_')[1].removesuffix('_END_CLIENT').lower()+' (unidentified)';cat='Prayer powders'
 elif any(x in n for x in ['_JUJU_','_PERFECT_PLUS_','_POTION_','HERB120_','POW_']):cat='Potions & skilling'
 elif n.startswith('COMBATV2_DEBUFF_') or any(x in n for x in ['_STUN_','_BIND_','_POISON_END_','_BLEED_']):cat='Debuffs on you'
 elif '_DEFENCE_' in n:cat='Defensive effects'
 elif any(x in n for x in ['_ATTACK_','_STRENGTH_','_MAGIC_','_RANGED_','_NECROMANCY_','_CONSTITUTION_']):cat='Combat effects'
 elif any(x in n for x in ['_ARCH_','_WOODCUTTING_','_SKILLING_']):cat='Potions & skilling'
 if n in aliases:label,cat,seconds=aliases[n]
 row={'id':n,'label':label,'category':cat,'experimental':True}
 if n=='COMBATV2_COOLDOWN_POISON_END_EFFECT_CLIENT':row['disabled']=True
 if seconds:row['seconds']=seconds
 rows.append(row)
rows.sort(key=lambda r:(r['category'],r['label'],r['id']))
def lua(v):
 if isinstance(v,str):return json.dumps(v,ensure_ascii=True)
 if isinstance(v,bool):return str(v).lower()
 return str(v)
output='-- Generated from the user-provided VarClient export; new bindings need live HUD validation.\n-- These are effect endpoints, not ability cooldowns or enemy-mechanic predictions.\nreturn {\n'
for r in rows:output+=' {'+','.join(k+'='+lua(v) for k,v in r.items())+'},\n'
output+='}\n'
(root/'src/effect_catalog.lua').write_text(output)
print(len(rows),'additional effect endpoints')
