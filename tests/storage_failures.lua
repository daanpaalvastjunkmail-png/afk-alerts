-- Fault injection against actual persistence, rather than mocking S.save.
local S=require('src/core/settings')
local P=require('src/core/presets')
local L=require('src/core/preset_library')
local d=S.defaults()
local id,c=S.add(d,'health');c.enabled=true;c.threshold=50
local original=P.export(d,'Saved alert list')
local db={[S.listKey]=original,['rs3_alerts.v1.presets.slot1']=P.export(d,'Personal preset')}
local failRead,failWrite
PersistentDB={
 GetString=function(_,key)if key==failRead then error('Storage unavailable')end;return db[key]end,
 GetBool=function(_,key)return db[key]end,
 SetString=function(_,key,value)if key==failWrite then return false end;db[key]=value;return true end,
 SetBool=function(_,key,value)if key==failWrite then return false end;db[key]=value;return true end,
}
failRead=S.listKey
local loaded=S.load()
assert(loaded.storageUnavailable and not S.save(loaded) and db[S.listKey]==original,
 'A failed read must not replace existing alerts with an empty list on shutdown')
P.apply(loaded,assert(P.resolve('Bossing')))
assert(not S.save(loaded),'Changing a draft cannot remove the read-failure guard')
failRead='rs3_alerts.v1.presets.slot1'
loaded=S.load()
assert(loaded.storageUnavailable and not S.save(loaded) and db['rs3_alerts.v1.presets.slot1']:find('Personal',1,true),
 'Unreadable preset slots must not be overwritten by empty defaults')
assert(not L.save(loaded,assert(L.open(original)),'Replacement'),'Preset writes also respect unreadable storage')
failRead=nil
loaded=S.load();assert(not loaded.storageUnavailable and loaded.showHelp==true,'Help defaults on when the preference is absent')
loaded.entries[id].threshold=25
failWrite='rs3_alerts.v1.masterVolume'
assert(not S.save(loaded) and db[S.listKey]==original,'Global write failure must not commit a new list')
failWrite=S.listKey
assert(not S.save(loaded) and db[S.listKey]==original,'List write failure preserves the previous record')
failWrite=nil
assert(S.save(loaded) and S.load().entries[id].threshold==25,'Successful retry persists the new list')
assert(db[S.listKey..'.backup']==original,'Previous valid running list is backed up')
local savedSlot=db['rs3_alerts.v1.presets.slot1']
loaded.presets.slot1=''
assert(S.save(loaded) and db['rs3_alerts.v1.presets.slot1']==savedSlot,'General saves never overwrite preset slots from an empty in-memory library')
loaded.presets.slot1=savedSlot
assert(L.rename(loaded,1,'Renamed preset'))
assert(db['rs3_alerts.v1.presets.slot1.backup']==savedSlot,'Explicit preset replacement retains the previous saved preset')
loaded.showHelp=false
assert(S.save(loaded) and S.load().showHelp==false,'Global help choice persists independently of presets')
P.apply(loaded,assert(P.resolve('Bossing')))
assert(loaded.showHelp==false,'Loading a preset does not change the global help preference')
print('Storage failures passed: unavailable reads, preset protection, partial writes and recovery')
