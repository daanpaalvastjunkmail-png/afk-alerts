-- Names confirmed by beta exports; live units checked against user snapshots.
local V = { version = "0.7.0", adapters = {}, status = {}, reported = {}, errors = {} }
V.names = {
 health = {"LIFEPOINTS", "MAXLIFEPOINTS"},
 adrenaline = {"SA_ENERGY", false},
 prayer = {"PRAYER_POINTS", false},
 summoning = {"LORE_POINTS", false},
}
-- Client adapters are installed in src/host.lua; missing readings stay explicit.
-- Drawing coordinates use API interface units. Cursor-following and native-HUD
-- component circles are outside the release scope; circles use monitor rows.
-- inventory() returns a complete snapshot { {id=..., count=...}, ... } or nil.
-- skill/timer return current value, maximum; timer units are seconds.
-- Audio uses OGG resources; volume is 0..1. MP3 names select the OGG equivalent.
function V.call(name, ...)
 local fn = V.adapters[name]
 if type(fn) ~= "function" then V.status[name] = "Not connected"; return nil end
 local ok, a, b = pcall(fn, ...)
 V.status[name] = ok and (a ~= nil and "Available" or "No data") or "API error"
 if ok then return a, b end
 V.report(name,a)
end
function V.noteUIError(message)
 local text=tostring(message):lower()
 if text:find("invalid dynamic id",1,true) then
  V.uiBlocked=true
  V.status.monitor="UI component IDs exhausted. Fully close and restart RuneScape."
  V.report("ui.limit",V.status.monitor)
 end
end
function V.safe(fn, ...)
 local ok, a, b = pcall(fn, ...)
 if ok then return a, b end
 V.noteUIError(a)
 V.status.callback = "API error"
 V.report("callback",a)
end
-- Print complete errors to the console, once per distinct error.
function V.report(name,message)
 local value=tostring(message)
 V.errors[name]=value
 local key=name..":"..value
 if not V.reported[key] then
  V.reported[key]=true
  pcall(print,"AFK ALERTS ["..name.."]: "..value)
 end
end
function V.finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
-- Permission requests are explicit user actions, dispatched outside UI callbacks.
-- Only HasPermission confirms consent; a successful console command does not.
function V.permission(name)
 local ok,granted=pcall(function()
  local permission=PluginPermissions[name]
  if permission==nil then return nil end
  return Plugin.HasPermission(permission)
 end)
 if not ok or type(granted)~="boolean" then return false,"unavailable" end
 return granted,granted and "enabled" or "disabled"
end
function V.permissionStatus(name,label)
 local _,status=V.permission(name)
 return label.." access "..status
end
function V.requestPermissions()
 V.permissionRequestPending=true
 V.status.permissions="Permission request queued. Choose which optional permissions to allow in the client."
end
function V.flushPermissionRequest()
 if not V.permissionRequestPending then return end
 V.permissionRequestPending=nil
 local ok,result=pcall(function()return ExecuteConsoleCommand("ppr rs3_alerts_plugin")end)
 if not ok or result==false then
  V.status.permissions="Permission request command failed. Open Plugin Hub > AFK ALERTS > padlock to manage permissions."
  return false
 end
 V.status.permissions="Permission request sent to the client. Check the current access statuses; the request itself does not grant access."
 return true
end
return V
