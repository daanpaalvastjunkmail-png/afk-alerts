-- One user-facing chooser for ordinary alerts and named effects.
-- Internal kinds/identifiers remain compatible with saved lists and presets.
local S=require('src/core/settings')
local T=require('src/timers')
local C={entries={},byID={},categories={},defaultCategory='Player resources',pageSize=20}
local core={
 {'health','Health','Player resources'}, {'prayer','Prayer','Player resources'},
 {'adrenaline','Adrenaline','Player resources'}, {'summoning','Summoning points','Player resources'},
 {'skill','Skill level','Skilling & inventory'}, {'idle','Skilling stopped','Skilling & inventory'},
 {'inventory','Inventory full','Skilling & inventory'}, {'drop','Drop alert','Loot drops'}, {'chat','Chat message','Chat messages'},
 {'overload','Overload','Potions & renewals'}, {'antifire','Antifire','Potions & renewals'},
 {'aggression','Aggression potion','Potions & renewals'}, {'familiar','Familiar duration','Familiars'},
}
local families={}
for kind,names in pairs(T.names) do for _,name in ipairs(names)do families[name]='core:'..kind end end
for _,item in ipairs(core)do
 C.entries[#C.entries+1]={id='core:'..item[1],kind=item[1],label=item[2],category=item[3]}
end
for _,option in ipairs(T.options)do
 if option.id~='' and not families[option.id] then
  C.entries[#C.entries+1]={id='effect:'..option.id,kind='buff',effect=option.id,label=option.label,category=T.catalog[option.id].category}
 end
end
table.sort(C.entries,function(a,b)if a.label==b.label then return a.id<b.id end;return a.label:lower()<b.label:lower()end)
local categories={}
for _,entry in ipairs(C.entries)do C.byID[entry.id]=entry;categories[entry.category]=true end
local names={};for name in pairs(categories)do names[#names+1]=name end;table.sort(names)
for _,name in ipairs(names)do C.categories[#C.categories+1]={id=name,label=name}end
function C.current(c)
 if c.type=='buff' then return 'effect:'..(c.buffID or '') end
 return 'core:'..c.type
end
function C.category(c)
 local entry=C.byID[C.current(c)]
 if entry then return entry.category end
 local legacy=c.type=='buff' and T.catalog[c.buffID]
 return legacy and legacy.category or C.defaultCategory
end
local aliases={
 ['core:health']='hp hitpoints life points lifepoints constitution gezondheid health',
 ['core:prayer']='pp pray prayer points gebed', ['core:adrenaline']='adr adren adrenaline adrenalin',
 ['core:summoning']='sum summ summon summoning points', ['core:overload']='ovl elder overload',
 ['core:antifire']='af anti fire dragonfire', ['core:aggression']='aggro agr aggression',
 ['core:familiar']='fam familiar summon timer', ['core:inventory']='inv bag backpack inventory full inventaris',
 ['core:idle']='afk idle xp skilling stopped inactivity', ['core:drop']='ge gp loot drops grand exchange price',
 ['core:chat']='text txt message trigger chat tekst bericht', ['core:skill']='level skill lvl',
}
local ignored={alert=true,alerts=true,notification=true,notifications=true,melding=true,alarm=true}
local function normalize(text)return text:lower():gsub('[^%w_]+',' '):match('^%s*(.-)%s*$')end
function C.options(category,query)
 query=normalize(query or '')
 local tokens={};for token in query:gmatch('%S+')do if not ignored[token]then tokens[#tokens+1]=token end end
 local searching=#tokens>0
 local entries,ranks={},{}
 local needle=table.concat(tokens,' ')
 for _,entry in ipairs(C.entries)do
  local match=searching or not category or category=='all' or entry.category==category
  local label=normalize(entry.label)
  local initials='';for word in label:gmatch('%S+')do initials=initials..word:sub(1,1)end
  local haystack=label..' '..(aliases[entry.id] or '')..' '..initials..' '..entry.id:lower()
  for _,token in ipairs(tokens)do if not haystack:find(token,1,true)then match=false;break end end
  if match then
   entries[#entries+1]=entry
   local rank=4
   if label==needle then rank=0
   elseif (' '..(aliases[entry.id] or '')..' '):find(' '..needle..' ',1,true) then rank=1
   elseif label:sub(1,#needle)==needle then rank=2
   elseif label:find(needle,1,true) then rank=3 end
   ranks[entry.id]=rank
  end
 end
 if searching then table.sort(entries,function(a,b)
  if ranks[a.id]~=ranks[b.id]then return ranks[a.id]<ranks[b.id]end
  if a.label==b.label then return a.id<b.id end
  return a.label:lower()<b.label:lower()
 end)end
 return entries
end
function C.create(identifier,previous)
 local entry=C.byID[identifier]
 if not entry then return nil,'Choose an alert' end
 local c=S.newAlert(entry.kind)
 if entry.effect then c.buffID=entry.effect end
 if entry.effect or T.names[entry.kind] then
  c.mode='absolute';c.direction='below';c.threshold=30;c.hysteresis=5;c.hysteresisMode='absolute'
  T.configure(c)
 end
 if previous then
  for _,key in ipairs({'name','volume','muted','visuals','bar','position','positionVersion','duration','enabled'})do c[key]=S.clone(previous[key]) end
  -- Keep a deliberately chosen sound, while allowing untouched defaults to follow the new type.
  local oldDefault=S.newAlert(previous.type)
  if oldDefault and previous.sound~=oldDefault.sound then c.sound=previous.sound end
 end
 return c
end
function C.apply(c,identifier)
 if C.current(c)==identifier then return true end
 local replacement,err=C.create(identifier,c)
 if not replacement then return nil,err end
 for key in pairs(c)do c[key]=nil end
 for key,value in pairs(replacement)do c[key]=value end
 return true
end
return C
