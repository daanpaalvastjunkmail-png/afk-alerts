-- Small persistent checkpoints for native failures that Lua cannot catch.
-- A saved checkpoint alone does not prove a crash or its cause.
local T={key="rs3_alerts.ui_checkpoint.v1"}
function T.mark(stage)
 T.last=require("src/core/vars").version.." | "..stage
 pcall(function() PersistentDB:SetString(T.key,T.last) end)
end
function T.reportPrevious()
 local ok,value=pcall(function() return PersistentDB:GetString(T.key) end)
 if ok and type(value)=="string" and value~="" then
  pcall(print,"AFK ALERTS: previous UI checkpoint (not a crash diagnosis): "..value)
 end
end
return T
