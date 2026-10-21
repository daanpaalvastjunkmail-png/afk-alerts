-- The native input retains at most 9,999 characters. Use smaller verified pages.
local X={pageSize=8000}
function X.new(field,note)
 local pager={field=field,note=note,page=1,pages=0,data=nil}
 function pager:render()
  if not self.data then return false end
  local first=(self.page-1)*X.pageSize+1
  local part=self.data:sub(first,first+X.pageSize-1)
  self.field:SetText(part,false)
  local retained=self.field:GetText()
  if retained~=part then
   self.field:SetText("",false)
   self.note.content=string.format("Export incomplete: field retained %d of %d characters. Original export data is retained.",type(retained)=='string' and #retained or 0,#part)
   return false
  end
  self.note.content=string.format("Part %d of %d · %d / %d characters total. Copy this part, then Next part; append all parts to one file in order.",self.page,self.pages,#part,#self.data)
  return true
 end
 function pager:show(data,err)
  self.data=nil;self.page=1;self.pages=0
  if not data then self.field:SetText("",false);self.note.content=err or "No recording available";return false end
  if data:find('[\r\n]') then self.field:SetText("",false);self.note.content="Export failed: expected one complete line";return false end
  self.data=data;self.pages=math.ceil(#data/X.pageSize)
  return self:render()
 end
 function pager:move(delta)
  if not self.data then return false end
  self.page=math.max(1,math.min(self.pages,self.page+delta))
  return self:render()
 end
 return pager
end
-- Compatibility helper for callers that only need the first page.
function X.show(field,note,data,err) return X.new(field,note):show(data,err) end
-- Retain large imports outside the capped native input. Never silently accept
-- a field which may have been clipped at its 9,999-character native limit.
local V=require("src/core/vars")
local Transfer=require("src/core/presets").transfer
local I={fieldLimit=9999}
function I.mount(page,state,notify)
 state.parts=state.parts or {};state.bytes=state.bytes or 0
 local field=page:AddTextField({text=state.text or "",height=36,maxLength=I.fieldLimit,
  onChange=function(_,_,text)if type(text)=="string" then state.text=text end end})
 local control={}
 function control:text()
  local text=field:GetText();state.text=text
  if type(text)~="string" then return nil,"Import field unavailable" end
  if #text>=I.fieldLimit then return nil,"Input reached the field limit. Clear import, then paste each exported part separately using Add part." end
  if state.bytes+#text>Transfer.maxLength then return nil,"Preset transfer is too large" end
  return table.concat(state.parts)..text
 end
 function control:clear()
  state.parts={};state.bytes=0;state.text="";field:SetText("",false)
 end
 page:AddSimpleButton("Add part",function()V.safe(function()
  local code,err=control:text()
  if not code then notify(err);return end
  local part=field:GetText()
  if part=="" then notify("Paste the next export part first.");return end
  state.parts[#state.parts+1]=part;state.bytes=state.bytes+#part;state.text="";field:SetText("",false)
  notify("Added "..#state.parts.." parts · "..state.bytes.." characters. Paste the next part, or import when complete.")
 end)end)
 page:AddSimpleButton("Clear import",function()V.safe(function()control:clear();notify("Import cleared.")end)end,{inline=true})
 if state.bytes>0 then notify("Import retained: "..#state.parts.." parts · "..state.bytes.." characters.")end
 return control
end
X.importer=I
return X
