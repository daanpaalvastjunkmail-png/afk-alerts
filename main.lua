-- Official Lua plugin. Every runtime entry owns its source and threshold state.
local ok,V=pcall(require,"src/core/vars")
if not ok then pcall(print,"AFK ALERTS: module loading failed: "..tostring(V)); return end
local function start()
 local Trace=require("src/ui/trace")
 Trace.reportPrevious()
 local openMonitor,pendingMonitor
 local S=require("src/core/settings")
 local E=require("src/core/alerts")
 local Sources=require("src/sources")
 local Aspects=require("src/aspects")
 local M=require("src/visual")
 local A=require("src/audio")
 local U=require("src/ui/dashboard")
 local SettingsHost=require("src/ui/settings_host")
 local HubSettings=require("src/ui/hub_settings")
 local H=require("src/host")
 local Prices=require("src/prices")
 local Highlight=require("src/highlighter")
 local Recorder=require("src/recorder")
 pcall(print,"AFK ALERTS: initialization started (build "..require("src/core/vars").version..")")
 local d=S.load()
 pcall(print,"AFK ALERTS: storage loaded: "..tostring(V.status.storageLoaded)..(d.storageUnavailable and " (read failed; saving blocked)" or d.storageReadError and " (saved list unreadable; retained)" or ""))
 H.install(); Prices.install()
 local function now() return V.call("clock") end
 local engine=E.new(function(id,c,sample,t) M.emit(id,c,sample,t); A.play(d,c) end)
 local subscriptions,readers,lastLootEvent={},{},{}
 local wasAvailable,lastTime
 local acceptLootAfter=0
 local uiStopped=false
 local function enabledLoot()
  for _,id in ipairs(d.entryOrder) do local c=d.entries[id]; if c.enabled and c.type=="drop" then return true end end
  return false
 end
 local function resetRuntime()
  engine.states={}; M.destroy(); M.samples={};M.sourceStatuses={}
  readers={}; lastLootEvent={}; Highlight.reset()
 end
 local function reset(id)
  if id then engine:reset(id); M.clear(id); readers[id]=nil; lastLootEvent[id]=nil
  else resetRuntime() end
  if not enabledLoot() then Prices.stop(); Prices.install() end
 end
 local function readerFor(id)
  if not readers[id] then readers[id]=Sources.new(); readers[id].lootAcceptAfter=acceptLootAfter end
  return readers[id]
 end
 local function test(id,override)
  local t=now(); if not V.finite(t) then return end
  local c=override or d.entries[id]
  if not c then return end
  local sample={value=50,maximum=100,message="Preview"}
  local target=c.type=="buff" and require("src/timers").targets[c.buffID]
  if target then
   sample.value=0;sample.presenceOnly=true;sample.message=target.label;sample.displayValue="Preview"
  end
  if c.type=="drop" then
   local label=c.dropMetric=="ge" and "GE" or c.dropMetric=="high_alch" and "High Alch" or nil
   sample.value=label and 50000 or 1; sample.maximum=label and 100000 or 100
   sample.displayValue=label and (label..": 50000 gp (preview)") or "1 item (preview)"
   sample.message=(c.itemNameFilter~="" and c.itemNameFilter or "Example loot").." x1 · "..sample.displayValue
  end
  M.emit(override and "__preview" or id,c,sample,t); A.play(d,c)
 end
 local function subscribe(name,fn)
  local subscribed=pcall(function() Event[name].Subscribe("rs3_alerts_"..name,function(event) V.safe(fn,event) end) end)
  V.status["event."..name]=subscribed and "Connected" or "Unavailable"
  if subscribed then subscriptions[#subscriptions+1]=name end
  return subscribed
 end
 local chatConnected,chatNext=false,0
 local function connectChat(t)
  if chatConnected or t<chatNext then return end
  chatNext=t+2
  if not require("src/chat").permission() then return end
  chatConnected=subscribe("ChatMessage",function(event)
  if not Player.IsAvailable() or not require("src/chat").permission() then return end
  require("src/chat").record(event,now())
  for _,id in ipairs(d.entryOrder) do
   local c=d.entries[id]
   if c.enabled and c.type=="chat" then readerFor(id):chatMessage(event,c,now()) end
  end
 end)
  if not chatConnected then V.status.chat="Chat event unavailable; retrying after permission is granted" end
 end
 subscribe("Logic",function(event)
  if event and V.finite(event.logicTick) then H.seconds=event.logicTick/50 end
  local t=now(); if not V.finite(t) then return end
  if lastTime and t<lastTime then
   resetRuntime();Aspects.reset();acceptLootAfter=t+3;chatNext=0
  end
  lastTime=t
  Recorder.tick(t)
  Prices.tick(t);require("src/chat").tick(t);connectChat(t)
  if V.uiBlocked then
   if not uiStopped then U.destroy(); SettingsHost.restore(); H.destroy(); uiStopped=true end
  else
   if pendingMonitor then
    pendingMonitor=false
    Trace.mark("monitor: dispatch on Logic")
    local opened,err=pcall(openMonitor)
    if not opened then
     Trace.mark("monitor: Lua error")
     V.noteUIError(err);V.report("monitor.open",err)
    end
   end
   if SettingsHost.tick() then U.destroy() end
   U.tick()
  end
  if not Player.IsAvailable() then
   if wasAvailable~=false then Aspects.reset();resetRuntime();require("src/chat").clearHistory() end
   wasAvailable=false; acceptLootAfter=t+3;return
  end
  if not wasAvailable then acceptLootAfter=t+3; readers={}; lastLootEvent={}; wasAvailable=true end
  Aspects.poll(t)
  Highlight.tick(d.highlighter,t)
  M.samples={};M.sourceStatuses={};M.conditions={}
  for _,id in ipairs(d.entryOrder) do
   V.safe(function()
    local c=d.entries[id]
    local sample,status
    if c.enabled then sample,status=readerFor(id):read(c.type,c,t)
    else
     if readers[id] then M.clear(id) end
     readers[id]=nil; lastLootEvent[id]=nil
    end
    if (c.type=="drop" or c.type=="chat") and sample and sample.eventID~=lastLootEvent[id] then
     engine:reset(id); lastLootEvent[id]=sample.eventID
    end
    if c.type=="buff" and Aspects.suppressed(c.buffID) then M.clear(id)end
    M.sourceStatuses[id]=status
    M.samples[id]=sample; engine:step(id,c,sample,t)
    M.conditions[id]=engine.states[id] and engine.states[id].active==true or false
   end)
  end
 end)
 subscribe("Draw",function()
  H.beginFrame()
  local t=now(); if V.finite(t) then M.draw(d,t); Highlight.draw(d.highlighter) end
 end)
 local function ground(event,kind)
  for _,id in ipairs(d.entryOrder) do
   local c=d.entries[id]
   if c.enabled and c.type=="drop" then readerFor(id):groundLoot(event,kind,now()) end
  end
 end
 subscribe("ObjStackEntityAdded",function(event) ground(event,"added") end)
 subscribe("ObjStackEntityChanged",function(event) ground(event,"changed") end)
 local function worldReset() Aspects.reset();acceptLootAfter=(now() or 0)+3; resetRuntime() end
 subscribe("WorldCreated",worldReset); subscribe("RegionCreated",worldReset); subscribe("GameStateChanged",worldReset)
 openMonitor=function()
  if V.uiBlocked then return end
  if SettingsHost.state and SettingsHost.state.window then
   SettingsHost.state.window:Show()
   if not U.context then
    U.mount(SettingsHost.state.window.content,d,test,reset,function(id,override) local c=override or d.entries[id];if c then A.play(d,c) end end)
   end
   return
  end
  U.destroy()
  Trace.mark("monitor: prepare")
  local parent=SettingsHost.prepare(nil,U.destroy,"list",d)
  Trace.mark("monitor: mount dashboard")
  U.mount(parent,d,test,reset,function(id,override) local c=override or d.entries[id]; if c then A.play(d,c) end end)
  Trace.mark("monitor: ready")
 end
 local function requestMonitor()
  if V.uiBlocked then return end
  Trace.mark("monitor: requested")
  pendingMonitor=true
 end
 subscribe("ContentLayerReady",requestMonitor)
 subscribe("SettingsLayerReady",function(event)
  if V.uiBlocked then return end
  HubSettings.mount(event.component,d,requestMonitor)
 end)
 pcall(print,"AFK ALERTS: ready; open AFK ALERTS from its cog or Plugins ribbon")
 function PluginShutdown()
  require("src/chat").clearHistory()
  pendingMonitor=false
  Trace.mark("shutdown: started")
  Recorder.stop("plugin-reload")
  for _,name in ipairs(subscriptions) do V.safe(function() Event[name].Unsubscribe("rs3_alerts_"..name) end) end
  HubSettings.destroy()
  Prices.stop(); S.save(d); U.destroy(); SettingsHost.restore(); M.destroy(); Highlight.reset(); H.destroy()
  Trace.mark("shutdown: complete")
 end
end
V.safe(start)
