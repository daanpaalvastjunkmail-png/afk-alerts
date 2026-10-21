local P=require('src/core/presets')
local S=require('src/core/settings')
local checks=0
local function check(value,message) assert(value,message); checks=checks+1 end
local function entry(data,index) return data.entries[data.entryOrder[index]] end
local d=S.defaults()
local id,c=S.add(d,'health'); c.enabled=true; c.threshold=50; c.name='Early warning'
local id2,c2=S.add(d,'health'); c2.enabled=true; c2.threshold=10; c2.volume=100; c2.name='Critical ; = % é'
c2.bar.x=-52
local code=P.export(d,'My duplicate health list','Shared example')
local parsed,err=P.decode(code); check(parsed,err)
check(#parsed.settings.entryOrder==2,'Duplicate types must round-trip as separate entries')
check(entry(parsed.settings,1).threshold==50 and entry(parsed.settings,2).threshold==10,'Preserve order and thresholds')
check(entry(parsed.settings,2).name==c2.name and entry(parsed.settings,2).bar.x==-52,'Encoded values and offsets')
check(P.decode('# Comment\n'..code:gsub(';','\n'))~=nil,'Text-file format')
for _,bad in ipairs({
 'return os.execute("oops")','RS3ALERTS/99;count=0','RS3ALERTS/2;count=33',
 'RS3ALERTS/2;count=1','RS3ALERTS/2;count=1;entries.1.type=unknown',
 'RS3ALERTS/2;count=1;entries.1.type=health;entries.1.enabled=yes',
 'RS3ALERTS/2;count=1;entries.1.type=health;entries.1.volume=101',
 'RS3ALERTS/2;count=1;entries.1.type=health;entries.1.threshold=nan',
 'RS3ALERTS/2;count=1;entries.1.type=health;entries.1.threshold=1e999',
 'RS3ALERTS/2;count=1;entries.1.type=health;entries.1.sound=..%2Fevil.mp3',
 'RS3ALERTS/2;count=1;entries.1.type=health;entries.1.mode=whatever',
 'RS3ALERTS/2;count=1;entries.1.type=idle;entries.1.skill=MADE_UP',
 'RS3ALERTS/2;count=0;highlighter.maxEntities=101',
 'RS3ALERTS/2;count=0;highlighter.maxEntities=2.5',
 'RS3ALERTS/2;count=0;highlighter.names=%XX',
 'RS3ALERTS/2;count=0;highlighter.names=%00',
 'RS3ALERTS/2;count=0;masterMuted=false',
 'RS3ALERTS/2;count=0;count=1',
 'RS3ALERTS/2;count=1;entries.1.type=health;entries.1.label=Fake',
 'RS3ALERTS/2;count=1;entries.1.type=health;entries.1.bar..x=5',
 'RS3ALERTS/2;count=1;entries.1.type=health;entries.2.type=health',
 string.rep('a',65537),
}) do check(P.decode(bad)==nil,'Reject invalid import: '..bad:sub(1,90)) end
local before=P.snapshot(d)
d.masterMuted=true; d.masterVolume=36; d.presets.slot2='keep me'
local fishing=assert(P.resolve('afk fishing'))
P.apply(d,fishing)
check(#d.entryOrder==2 and entry(d,1).type=='idle' and entry(d,1).skill=='FISHING','Activity template')
check(d.masterMuted and d.masterVolume==36 and d.presets.slot2=='keep me','Keep global audio and slots')
entry(fishing.settings,1).threshold=999
check(entry(d,1).threshold==30,'Applied list does not alias preset data')
P.restore(d,before)
check(entry(d,1).threshold==50 and entry(d,2).threshold==10,'Undo restores complete ordered list')
check(entry(d,1)~=entry(d,2),'Duplicate entries are independent objects')
local old=assert(P.decode('RS3ALERTS/1;name=Old;alerts.health.enabled=true;alerts.health.threshold=45;alerts.prayer.listed=true'))
check(#old.settings.entryOrder==2 and entry(old.settings,1).threshold==45 and not entry(old.settings,2).enabled,'Migrate old shared presets, including paused rows')
local library=P.builtins()
check(#library==8,'Four general presets plus four requested Gregorovic styles')
local expected={'AFK Skilling','Overload Timer','Drop Alert','Bossing','Gregorovic AFK - Magic','Gregorovic AFK - Melee','Gregorovic AFK - Necromancy','Gregorovic AFK - Ranged'}
for i,name in ipairs(expected) do check(library[i].label==name,'Plain preset name and stable order') end
local boss=assert(P.resolve('Bossing')).settings
check(#boss.entryOrder==4,'Bossing has exactly four alerts')
check(entry(boss,1).type=='drop' and entry(boss,1).dropMetric=='ge' and entry(boss,1).threshold==100000 and entry(boss,1).direction=='above','Bossing uses GE drops above 100k')
check(entry(boss,2).type=='health' and entry(boss,2).threshold==30 and entry(boss,2).mode=='percent','Bossing health below 30 percent')
check(entry(boss,3).type=='prayer' and entry(boss,3).threshold==20,'Bossing prayer below 20 percent')
check(entry(boss,4).type=='overload' and entry(boss,4).mode=='absolute' and entry(boss,4).threshold==30,'Bossing overload below 30 seconds')
for _,item in ipairs(library) do check(P.decode(item.text)~=nil,'Every built-in template validates') end
check(P.preview(assert(P.resolve('boss'))):find('UNVERIFIED DATA SOURCES',1,true),'Do not imply vitals are verified')
local db={}
PersistentDB={SetBool=function(_,k,v) db[k]=v; return true end,SetString=function(_,k,v) db[k]=v; return true end,
 GetBool=function(_,k) return db[k] end,GetString=function(_,k) return db[k] end}
check(require('src/core/preset_library').save(d,assert(require('src/core/preset_library').open(code)))==1,'Explicitly save preset slot')
check(S.save(d),'Save full model')
local loaded=S.load()
check(#loaded.entryOrder==2 and entry(loaded,1).threshold==50 and entry(loaded,2).threshold==10,'Persist independent entries')
check(loaded.presets.slot1==code,'Persist saved list slot')
S.remove(loaded,loaded.entryOrder[1]); check(S.save(loaded),'Save removal')
check(#S.load().entryOrder==1 and entry(S.load(),1).threshold==10,'Removed entries cannot return from stale keys')
db={['rs3_alerts.v1.alerts.health.enabled']=true,['rs3_alerts.v1.alerts.health.threshold']='55',
 ['rs3_alerts.v1.alerts.prayer.listed']=true}
loaded=S.load()
check(#loaded.entryOrder==2 and entry(loaded,1).threshold==55 and not entry(loaded,2).enabled,'Migrate old persistent configuration')
local full=S.defaults()
for i=1,S.maxEntries do check(S.add(full,'health')~=nil,'Fill independent entry list') end
check(S.add(full,'health')==nil,'Bound list size')
check(P.decode(P.export(full))~=nil,'Maximum-size list round-trip')
db={[S.listKey]='RS3ALERTS/99;count=1'}
local unreadable=S.load()
check(unreadable.storageReadError and #unreadable.entryOrder==0,'Invalid saved list is not treated as a valid empty list')
check(not S.save(unreadable) and db[S.listKey]=='RS3ALERTS/99;count=1','Do not overwrite unreadable saved data on shutdown')
P.apply(unreadable,assert(P.resolve('fishing')))
check(S.save(unreadable),'Explicit preset replacement can recover the list')
print(checks..' preset checks passed: duplicate instances, validation, ordered lists, migration, undo and persistence')
