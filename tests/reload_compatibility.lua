-- Reproduce a running client whose resource inventory predates new Lua files.
local original=require
local unavailable={["src/version"]=true,["src/core/preset_transfer"]=true,["src/ui/preset_import"]=true}
require=function(name)
 if unavailable[name] then return nil end
 local value=original(name)
 if name:match("^src/") then assert(type(value)=="table","Client modules must export tables: "..name)end
 return value
end
dofile("tests/runtime_lifecycle.lua")
assert(original("src/core/vars").version=="0.7.0")
local P=original("src/core/presets")
local code=assert(P.transfer.encode(P.builtins()[1].text))
assert(original("src/core/preset_library").import(code))
assert(type(original("src/ui/recording_export").importer.mount)=="function")
print("Reload compatibility passed: startup, events and preset sharing without discovering new modules")
