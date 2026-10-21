-- Own non-modal floating windows. Never hide or disable a native Hub modal.
local Trace=require("src/ui/trace")
local V=require("src/core/vars")
local Position=require("src/ui/window_position")
local Grip=require("src/ui/window_grip")
local W={state=nil}
function W.restore()
 local state=W.state
 W.state=nil
 if not state then return end
 if state.editorWindow then V.safe(function() Position.save(state.editorWindow);state.editorWindow:Destroy() end) end
 if state.window then V.safe(function() Position.save(state.window);state.window:Destroy() end) end
end
local function dimensions(area,mode,d)
 local width,height=820,580
 if mode=="list" then
  local count=d and d.entryOrder and #d.entryOrder or 0
  width=340; height=math.min(440,math.max(254,182+count*72))
 elseif mode=="add" then width=820; height=580
 elseif mode=="presets" then width=640;height=540 end
 return math.min(width,math.max(240,area.width-48)),math.min(height,math.max(200,area.height-48))
end
local function createWindow(state,mode,d,onClose)
 local width,height=dimensions(state.area,mode,d)
 local monitor=mode=="list"
 local title=monitor and "AFK ALERTS" or mode=="add" and "Add an alert" or mode=="presets" and "AFK ALERTS Presets" or mode=="edit" and "Edit alert" or "AFK ALERTS Settings"
 local x=monitor and 24 or math.floor((state.area.width-width)/2)
 -- Put the editor alongside the monitor whenever the game area is wide enough.
 if not monitor and state.area.width>=width+428 then x=428 end
 local y=math.floor((state.area.height-height)/2)
 x,y=Position.load(monitor and "monitor" or "editor",state.area,width,height,x,y)
 Trace.mark("window "..mode..": PrettyUI.Window.new")
 local window=prettyui.Window.new(state.area,{
  title=title,width=width,height=height,x=x,y=y,
  resizable=true,minWidth=monitor and 280 or math.min(480,width),minHeight=monitor and 248 or math.min(320,height),
  scrollable=false,onClose=function(closed) Position.save(closed);if onClose then V.safe(onClose) end end,
 })
 -- Resize only the close control on our own PrettyUI window. The larger
 -- button stays inside the existing title-bar exclusion used for dragging.
 if window.closeButton then V.safe(function()
  window.closeButton:SetPos(-32,3,1.0)
  window.closeButton:SetSize(28,28)
 end) end
 Trace.mark("window "..mode..": Show")
 window.positionKind=monitor and "monitor" or "editor"
 window:Show()
 V.safe(function()Grip.install(window)end)
 V.status.settingsWindow=title..": "..width.." × "..height
 return window,width,height
end
function W.closeEditor()
 local state=W.state
 if state and state.editorWindow then
  local window=state.editorWindow; state.editorWindow=nil
  V.safe(function() Position.save(window);window:Destroy() end)
 end
end
function W.setMode(mode,d,onClose)
 assert(not V.uiBlocked,"UI unavailable: fully close and restart RuneScape")
 local state=assert(W.state,"Settings window is not open")
 if mode~="list" then
  W.closeEditor()
  state.editorWindow=createWindow(state,mode,d,onClose)
  return state.editorWindow.content
 end
 local width,height=dimensions(state.area,"list",d)
 if not state.window then
  state.window,state.width,state.height=createWindow(state,"list",d,state.onClose)
 elseif not state.monitorSizedByUser and (state.width~=width or state.height~=height) then
  state.window:SetSize(width,height); state.width=width; state.height=height
 end
 state.monitorContentWidth=state.window.content.width
 state.monitorContentHeight=state.window.content.height
 return state.window.content
end
function W.prepare(layer,onClose,mode,d)
 W.restore()
 assert(not V.uiBlocked,"UI unavailable: fully close and restart RuneScape")
 local area=V.call("gameArea")
 assert(area and area.width>0 and area.height>0,"Game UI layer unavailable")
 local state={area=area,onClose=onClose}
 W.state=state
 local ok,result=pcall(function()
  local content=W.setMode(mode or "settings",d,onClose)
  return content
 end)
 if not ok then V.noteUIError(result); W.restore(); error(result) end
 return result
end
function W.tick()
 local state=W.state
 if not state then return false end
 Position.tick(state.window);Position.tick(state.editorWindow)
 V.safe(function()Grip.update(state.window);Grip.update(state.editorWindow)end)
 if state.window then
  local content=state.window.content
  if state.monitorContentWidth and (content.width~=state.monitorContentWidth or content.height~=state.monitorContentHeight) then
   state.monitorSizedByUser=true
  end
  state.monitorContentWidth=content.width; state.monitorContentHeight=content.height
 end

 return false
end
return W
