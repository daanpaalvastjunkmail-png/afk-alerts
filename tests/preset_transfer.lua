local S=require('src/core/settings')
local P=require('src/core/presets')
local T=require('src/core/presets').transfer
local L=require('src/core/preset_library')
local I=require('src/ui/recording_export').importer
local d=S.defaults()
for i=1,32 do
 local _,c=S.add(d,'chat');c.enabled=true;c.chatText=string.rep('a',400)..i;c.name='Chat '..i
end
local raw=P.export(d,'Large preset')
local shared=assert(T.encode(raw))
assert(#shared>16000 and T.decode(shared)==raw)
assert(#assert(L.import(shared)).data.entryOrder==32)
for _,last in ipairs({12,9999,#shared-1})do
 assert(not L.import(shared:sub(1,last)),'Truncated transfer must be rejected')
end
assert(not L.import(shared:gsub('Chat%%201','Chat%%209',1)),'Same-length corruption must fail checksum')
assert(L.import(raw) and L.import('fishing'),'Legacy preset codes and activity names remain importable')
local parts={}
for first=1,#shared,8000 do parts[#parts+1]=shared:sub(first,first+7999)end
assert(L.import(table.concat(parts,'\n')),'Text-file page line breaks are accepted')
parts[1],parts[2]=parts[2],parts[1]
assert(not L.import(table.concat(parts)),'Out-of-order pages must fail')
parts[1],parts[2]=parts[2],parts[1]
local buttons,field={},nil
local page={}
function page:AddTextField(o)
 local f={text=o.text}
 function f:GetText()return self.text end
 function f:SetText(text)self.text=text:sub(1,9999)end
 field=f;return f
end
function page:AddSimpleButton(label,fn)buttons[label]=fn end
local state,note={},nil
local control=I.mount(page,state,function(text)note=text end)
field:SetText(shared)
assert(#field.text==9999 and not control:text(),'Clipped native field must be rejected')
buttons['Add part']();assert(state.bytes==0 and note:find('field limit',1,true))
buttons['Clear import']()
for _,part in ipairs(parts)do field:SetText(part);buttons['Add part']()end
assert(control:text()==shared and #assert(L.import(control:text())).data.entryOrder==32)
control=I.mount(page,state,function(text)note=text end)
assert(control:text()==shared,'Closing/reopening the sharing view retains accumulated parts')
control:clear();assert(state.bytes==0 and #state.parts==0 and field.text=='')
field:SetText(parts[1]);buttons['Add part']()
assert(not L.import(control:text()),'Importing too early cannot accept a partial preset')
control:clear()
field:SetText('fishing');assert(L.import(control:text()),'Short ordinary imports remain one step')
print('Preset transfer passed: 32-alert multi-part round trip, native clipping, missing/reordered/damaged parts, legacy imports and retained input')
