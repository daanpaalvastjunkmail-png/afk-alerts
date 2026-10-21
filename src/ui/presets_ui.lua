local V=require("src/core/vars")
local S=require("src/core/settings")
local P=require("src/core/presets")
local L=require("src/core/preset_library")
local Transfer=require("src/core/presets").transfer
local Import=require("src/ui/recording_export").importer
local UI={draft="",name="My preset",slot=1,message="Choose a preset to load, edit or export. Included presets are available in the same list."}
local function button(page,label,fn,inline,disabled)
 return page:AddSimpleButton(label,function()V.safe(fn)end,{inline=inline==true,disabled=disabled==true})
end
function UI.editorOptions(refresh)
 if UI.session and UI.session.editHighlights then
  return {section="highlights",data=UI.session.data,localOnly=true,backLabel="Back to preset",back=function()
   UI.session.editHighlights=nil;UI.message="Highlight changes are in the draft. Click Save preset to store them.";refresh()
  end}
 end
 local edit=UI.alertDraft
 if not edit or not UI.session then return nil end
 local function back()UI.alertDraft=nil;refresh()end
 return {draft=edit.config,isNew=edit.isNew,back=back,
  changeType=function(kind)edit.config=S.newAlert(kind);edit.config.enabled=true;refresh()end,
  commit=function(c)
   local session=UI.session
   if edit.isNew then
    local id,err=S.add(session.data,c.type,c)
    if not id then return nil,err end
   else session.data.entries[edit.id]=S.clone(c) end
   UI.message="Alert updated in draft. Click Save preset to store it."
   back();return true
  end}
end
function UI.mount(page,d,reset,refresh,highlights)
 local function remount(message)if message then UI.message=message end;refresh()end
 local function open(code,slot,standard)
  local session,err=L.open(code,slot)
  if not session then UI.exportOnOpen=nil;remount("Cannot open preset: "..tostring(err));return end
  if slot then UI.selectedSlot=slot end
  session.standard=standard
  UI.session=session;UI.alertDraft=nil;remount("Editing "..session.name.." as a draft. Save preset stores it; Load activates the saved version.")
 end
 local function load(code)
  local name,err,undo=L.load(d,code,reset)
  UI.undo=undo or UI.undo
  if name then UI.lastLoadedName=name end
  remount(name and ("Loaded "..name..". These alerts are now running.") or tostring(err))
 end
 page:AddTitle(UI.session and "Preset settings" or "Presets")
 local status=page:AddText({text=UI.message,height=62,maxLines=3})
 local function message(text)UI.message=text;status.content=text end
 if UI.session then
  local session=UI.session
  if UI.discardPending then
   page:AddText({text="This preset has unsaved changes. Discard them and return to the list?",height=66,maxLines=3})
   button(page,"Discard changes",function()UI.discardPending=nil;UI.session=nil;UI.alertDraft=nil;remount("Unsaved draft discarded.")end)
   button(page,"Keep editing",function()UI.discardPending=nil;remount()end,true)
   return
  end
  local name
  button(page,"Back to presets",function()
   session.name=name:GetText()
   if L.hasChanges(session,session.name)then UI.discardPending=true;remount();return end
   UI.session=nil;UI.alertDraft=nil;remount()
  end)
  page:AddText(session.standard and "Included preset. Save makes your own saved version; the original stays available." or "Edit your saved preset. Save keeps it in the library; Save & load also activates it.")
  page:AddText("Preset name (edit to rename)")
  name=page:AddTextField({text=session.name,height=32,maxLength=80})
  local function savePreset(andLoad)
   local slot,err=L.save(d,session,name:GetText())
   if not slot then message(err);return end
   UI.selectedSlot=slot;UI.selectedID=slot;UI.filter="";session.standard=nil
   if andLoad then load(d.presets["slot"..slot])else remount("Saved "..session.name..". Running alerts are unchanged; use Load to activate it.")end
  end
  button(page,"Save preset",function()savePreset(false)end)
  button(page,"Save & load",function()savePreset(true)end,true)
  button(page,"Save as copy",function()
   local copy,err=L.copy(d,session,name:GetText())
   if not copy then message(err);return end
   UI.session=copy;UI.selectedSlot=copy.slot;UI.selectedID=copy.slot;UI.filter="";remount("Saved separate copy: "..copy.name..".")
  end,true)
  if session.slot then
   button(page,"Load saved preset",function()load(d.presets["slot"..session.slot])end)
   button(page,"Rename preset",function()
    local slot,err=L.rename(d,session.slot,name:GetText())
    if not slot then message(err);return end
    local saved=d.presets["slot"..slot]
    session.name=assert(P.decode(saved)).name;session.originalCode=saved;UI.filter=""
    remount("Renamed saved preset. Other draft changes still need Save preset.")
   end,true)
  end
  page:AddTitle("Alerts in this preset")
  for _,id in ipairs(session.data.entryOrder)do
   local c=session.data.entries[id]
   page:AddText(S.title(c))
   page:AddCheckboxButton({{text="Enabled",value=id,selected=c.enabled}},{onChange=function(_,_,_,selected)
    V.safe(function()if type(selected)=="boolean" then c.enabled=selected end end)
   end})
   button(page,"Edit",function()
    session.name=name:GetText();UI.alertDraft={id=id,config=S.clone(c)};remount()
   end)
   button(page,"Remove",function()session.name=name:GetText();S.remove(session.data,id);remount()end,true)
  end
  button(page,"Add alert",function()
   session.name=name:GetText()
   local c=require("src/core/alert_catalog").create("core:health");c.enabled=true
   UI.alertDraft={isNew=true,config=c};remount()
  end)
  button(page,"Edit preset highlights",function()
   session.name=name:GetText();session.editHighlights=true;remount()
  end)
  page:AddTitle("Copy / export preset")
  page:AddText("Exports this preset, including unsaved draft edits. Copy each part with Ctrl+A then Ctrl+C and append in order. Import it in another installation; custom sound files are separate.")
  local note=page:AddText({text="Click Export preset to prepare the code.",height=60,maxLines=3})
  local output=page:AddTextField({text="",height=36,maxLength=8000})
  local pager=require("src/ui/recording_export").new(output,note)
  button(page,"Export preset",function()
   local code,err=L.export(session,name:GetText());pager:show(Transfer.encode(code,err))
  end)
  if UI.exportOnOpen then UI.exportOnOpen=nil;local code,err=L.export(session,name:GetText());pager:show(Transfer.encode(code,err))end
  button(page,"Previous part",function()pager:move(-1)end)
  button(page,"Next part",function()pager:move(1)end,true)
  page:SetScrollable(true);return
 end
 if UI.deletePending then
  local pending=UI.deletePending
  page:AddTitle("Delete preset?")
  page:AddText({text="Delete "..pending.name.." from your saved presets? Running alerts keep working. You can undo the latest deletion during this session.",height=110,maxLines=5})
  button(page,"Confirm delete",function()
   local deleted,err=L.delete(d,pending.slot,pending.code)
   if not deleted then message(err);return end
   UI.deleted=deleted;UI.deletePending=nil;UI.selectedSlot=nil;UI.selectedID=nil;UI.filter=""
   remount("Deleted "..pending.name..". Running alerts are unchanged.")
  end)
  button(page,"Cancel delete",function()UI.deletePending=nil;remount("Deletion cancelled.")end,true)
  return
 end
 page:AddText("One library for your saved presets and the included presets. Load activates alerts; Edit opens a separate draft.")
 if UI.lastLoadedName then page:AddText("Last loaded: "..UI.lastLoadedName)end
 if UI.showStandards==nil then
  local ok,value=pcall(function()return PersistentDB:GetBool("rs3_alerts.presetLibrary.showStandard")end)
  UI.showStandards=not(ok and value==false)
 end
 local search,importer
 page:AddCheckboxButton({{text="Show included presets",value="standard",selected=UI.showStandards}},{onChange=function(_,_,_,selected)
  if type(selected)=="boolean" and selected~=UI.showStandards then
   UI.showStandards=selected
   pcall(function()PersistentDB:SetBool("rs3_alerts.presetLibrary.showStandard",selected)end)
   UI.filter=search and search:GetText() or UI.filter
   if importer then importer:text()end
   UI.selectedID=nil;remount()
  end
 end})
 page:AddText("Search presets (press Enter)")
 search=page:AddTextField({text=UI.filter or "",height=32,maxLength=80,tooltip="Search preset names; press Enter.",onSubmit=function(_,text)
  UI.filter=text;UI.selectedID=nil
  if importer then importer:text()end
  remount()
 end})
 if UI.filter and UI.filter~="" then button(page,"Clear search",function()
  if importer then importer:text()end
  UI.filter="";UI.selectedID=nil;remount()
 end)end
 local items=L.list(d,UI.filter,UI.showStandards)
 local byID,entries={},{}
 -- Explicit order uses PrettyUI's ordered selector, avoiding native ComboField
 -- ID/position disagreement between the selected entry and its header label.
 for index,item in ipairs(items)do byID[item.id]=item;entries[#entries+1]={id=item.id,label=item.label,order=index}end
 local current=byID[UI.selectedID or UI.selectedSlot]
 if not current then
  current=items[1]
  if current and current.standard then for _,item in ipairs(items)do if item.key=="standard:boss" then current=item;break end end end
 end
 if current then
  UI.selectedID=current.id;UI.selectedSlot=current.slot
  page:AddComboBox({entries=entries,selectedID=current.id,onChange=function(_,id)
   if byID[id] and id~=UI.selectedID then
    UI.selectedID=id;UI.selectedSlot=byID[id].slot
    UI.filter=search:GetText()
    if importer then importer:text()end
    remount()
   end
  end})
  page:AddText(current.standard and "Included preset · editing creates your own version." or "Your saved preset · Save updates this same preset.")
  if current.preset then page:AddText(tostring(#current.preset.settings.entryOrder).." alerts in "..current.name)end
  button(page,"Load selected preset",function()load(current.code)end)
  button(page,"Edit selected preset",function()open(current.code,current.slot,current.standard)end,true)
  button(page,"Export selected preset",function()UI.exportOnOpen=true;open(current.code,current.slot,current.standard)end)
  button(page,"Delete preset",function()
   if current.standard then message("Included presets cannot be deleted. Save your own version to edit or delete it.");return end
   UI.deletePending={slot=current.slot,code=current.code,name=current.name};remount()
  end,true,current.standard)
 else page:AddText("No presets match this search.")end
 button(page,"Save current alerts as preset",function()open(P.export(d,"My preset"))end)
 button(page,"New empty preset",function()open(P.export(S.defaults(),"New preset"))end,true)
 if UI.deleted then button(page,"Undo delete",function()
  local slot,err=L.restoreDeleted(d,UI.deleted)
  if not slot then message(err);return end
  UI.deleted=nil;UI.selectedSlot=slot;UI.selectedID=slot;UI.filter="";remount("Deleted preset restored.")
 end)end
 if UI.undo then button(page,"Undo last load",function()P.restore(d,UI.undo);UI.undo=nil;reset();S.save(d);remount("Previous alerts restored.")end)end
 if highlights then button(page,"Edit current entity highlights",highlights)end
 page:AddTitle("Import preset")
 page:AddText("Paste a short code or activity name. For large exports, paste each part and click Add part, then Import preset. Import opens a draft without replacing running alerts.")
 UI.importState=UI.importState or {text=UI.draft}
 importer=Import.mount(page,UI.importState,message)
 button(page,"Import preset",function()
  local code,err=importer:text()
  if not code then message(err);return end
  local session;session,err=L.import(code)
  if not session then message("Cannot import: "..tostring(err));return end
  importer:clear()
  UI.session=session;UI.alertDraft=nil;remount("Imported preset. Review it, then Save preset.")
 end)
 page:SetScrollable(true)
end
-- The monitor now handles loading, editing, saving, renaming and deletion.
-- This compact companion is only for sharing and optional highlight settings.
function UI.mountSharing(page,d,reset,refresh,highlights)
 local Q=require("src/ui/quick_presets");Q.sync(d)
 local selected=Q.current(d)
 page:AddTitle("Share presets")
 page:AddText("Choose and edit presets in the alert monitor. Save stores your current alerts; the pencil renames and the trash removes a saved preset.")
 local label=selected and selected.name or "My preset"
 page:AddText("Selected preset: "..label..". Save in the monitor first to include your latest edits.")
 local status=page:AddText({text=UI.shareMessage or "Export the selected saved preset, or import a shared preset below.",height=44,maxLines=2})
 local function message(text)UI.shareMessage=text;status.content=text end
 page:AddText("Export code · copy every part with Ctrl+A then Ctrl+C")
 local output=page:AddTextField({text="",height=30,maxLength=8000})
 local pager=require("src/ui/recording_export").new(output,status)
 local function exportCurrent()
  local ok,code=pcall(P.export,d,label,selected and selected.preset and selected.preset.description or "")
  if not ok then message(tostring(code));return end
  pager:show(Transfer.encode(code))
 end
 button(page,"Export current alerts",exportCurrent)
 if UI.shareExportOnOpen then
  UI.shareExportOnOpen=nil
  if selected then pager:show(Transfer.encode(selected.code))else exportCurrent()end
 end
 button(page,"Previous part",function()pager:move(-1)end,true)
 button(page,"Next part",function()pager:move(1)end,true)
 page:AddText("For large presets: paste one export part, click Add part, repeat for every part, then Import & load. Short codes can be pasted and imported directly.")
 page:AddText("Import preset code")
 UI.shareImportState=UI.shareImportState or {text=UI.shareInput or ""}
 local importer=Import.mount(page,UI.shareImportState,message)
 button(page,"Import & load",function()
  local code,err=importer:text()
  if not code then message(err);return end
  local ok;ok,err=Q.import(d,code,reset)
  if not ok then message(err);return end
  importer:clear();message(Q.message..". Select it in the monitor to edit or rename it.")
 end)
 if highlights then button(page,"Edit entity highlights",highlights,true)end
 page:AddText("Imports are saved as personal presets. An existing name creates a separate copy. Audio files must be transferred separately.")
 page:SetScrollable(true)
end
return UI
