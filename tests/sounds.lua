local A=require('src/audio')
package.loaded['src/custom_sounds']={{id='custom_bell.mp3',label='Bell.mp3 (custom)'}}
Plugin={resources={sounds={health={},custom_bell={},manual_bell={}}}}
local entries=A.catalog('missing.mp3')
local seen={}
for _,entry in ipairs(entries) do
 assert(not seen[entry.id],'Sound IDs must be unique')
 seen[entry.id]=entry.label
end
assert(seen['custom_bell.mp3']=='Bell.mp3 (custom)')
assert(not seen['custom_bell.ogg'] and not seen['health.ogg'],'Do not duplicate MP3 aliases as OGG sounds')
assert(seen['manual_bell.ogg'] and seen['health.mp3'])
assert(seen['missing.mp3']=='missing.mp3 (saved selection)','Preserve saved selections')
Plugin=nil
assert(#A.catalog()==11,'Catalogue must also work without resource discovery')
Plugin={resources={sounds={health={path='/home/player/RS3/resources/sounds/health.ogg'}}}}
assert(A.soundFolder()=='/home/player/RS3/resources/sounds')
Plugin.resources.sounds.health.path=[=[C:\Users\Player\Plugins\rs3_alerts_plugin\resources\sounds\health.ogg]=]
assert(A.soundFolder()=='C:/Users/Player/Plugins/rs3_alerts_plugin/resources/sounds')
Plugin.resources={alert_health={path='/Users/Player/Plugins/rs3_alerts_plugin/resources/alert_health.ogg'}}
assert(A.soundFolder()=='/Users/Player/Plugins/rs3_alerts_plugin/resources/sounds')
Plugin.resources.alert_health.path='resources/alert_health.ogg'
assert(A.soundFolder()==nil,'Never present a relative resource path as an absolute folder')
Plugin=nil
assert(A.soundFolder()==nil,'Unknown host APIs must degrade safely')
print('Sound catalogue/path checks passed: imports, saved selections and Windows/macOS/Linux paths')

local names={}
for _,entry in ipairs(A.builtins)do names[entry.label]=true end
for _,name in ipairs({'Sine','Saw','Square','Alarm','Ring','Beep','Chime','Siren','Double Alarm','Urgent Pulse'})do assert(names[name..' (built-in)'])end
assert(#A.builtins==10)
for _,entry in ipairs(A.catalog('basic_triangle.ogg'))do assert(not entry.label:find('Triangle',1,true),'Triangle is removed from the picker even for saved presets')end
local selected=A.catalog('prayer.mp3');local builtinCount=0
for _,entry in ipairs(selected)do
 if entry.label:find('(built-in)',1,true)then builtinCount=builtinCount+1 end
 if entry.id=='prayer.mp3' then assert(entry.label=='Sine (built-in)','Old presets retain a selected, recognizable tone')end
end
assert(builtinCount==10,'Saved legacy tones never add extra builtin choices')
Plugin={resources={sounds={health={},prayer={},basic_square={},basic_ring={},manual={}}}}
local discovered=A.catalog();local count=0
for _,entry in ipairs(discovered)do
 if entry.label:find('(built-in)',1,true)then count=count+1 end
 assert(entry.id~='basic_square.mp3' and entry.id~='basic_ring.mp3' and entry.id~='prayer.ogg')
end
assert(count==10,'Resource discovery does not duplicate new or legacy builtins')
local V=require('src/core/vars');local played
V.adapters.audio=function(path,volume)played={path,volume}end
local settings={masterMuted=false,masterVolume=50}
for _,sound in ipairs({'prayer.mp3','buff.ogg','HEALTH.MP3'})do
 A.play(settings,{sound=sound,volume=80,muted=false});assert(played[1]=='sounds/health.mp3' and played[2]==0.4)
end
A.play(settings,{sound='basic_triangle.ogg',volume=100});assert(played[1]=='sounds/health.mp3','Old Triangle selections fall back to Sine')
A.play(settings,{sound='custom_bell.mp3',volume=100});assert(played[1]=='sounds/custom_bell.mp3','Custom audio is not remapped')
played=nil;A.play(settings,{sound='../health.mp3',volume=100});assert(played==nil)
settings.masterMuted=true;A.play(settings,{sound='basic_alarm.ogg',volume=100});assert(played==nil)
print('Basic sounds passed: ten choices, legacy aliases, resource discovery, custom preservation, volume and mute')
