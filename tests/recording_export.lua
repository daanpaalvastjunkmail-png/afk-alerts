local X=require('src/ui/recording_export')
local note={};local field={text=''}
function field:SetText(value)self.text=value:match('^[^\r\n]*'):sub(1,9999)end
function field:GetText()return self.text end
field:SetText('RS3DIAG/1\nSTART,10\nSTOP,20,manual')
assert(field:GetText()=='RS3DIAG/1','Reproduce old newline failure')
local data='RS3DIAG/2;START,10;D,1,P,13655,LIFEPOINTS;V,11,1,9900;STOP,20,manual'
assert(X.show(field,note,data) and field:GetText()==data)
assert(note.content:find('Part 1 of 1',1,true))
local long='RS3DIAG/2;'..string.rep('x',27086)..';STOP,20,manual'
local pager=X.new(field,note);assert(pager:show(long))
assert(pager.pages==4 and #field.text==8000,'27 KB recording uses four safe parts')
local copied={}
for i=1,pager.pages do
 assert(pager.page==i and #field.text<=8000)
 copied[#copied+1]=field.text
 pager:move(1)
end
assert(table.concat(copied)==long,'Copying all parts retains every character and correct order')
assert(pager.page==4);pager:move(-1);assert(pager.page==3)
pager:show(data);assert(pager.page==1 and pager.pages==1,'A new Show resets export pagination')
function field:SetText(value)self.text=value:sub(1,16)end
assert(not X.show(field,note,data) and field.text=='')
assert(note.content:find('16 of '..#data..' characters',1,true),'Truncation never reports success')
assert(not X.show(field,note,nil,'Stop recording first') and note.content=='Stop recording first')
assert(not X.show(field,note,'RS3DIAG/1\nSTART,1') and field.text=='')
print('Recording export passed: 9,999-character native limit, safe pages, exact reconstruction, navigation and truncation checks')
