local saved,printed
PersistentDB={SetString=function(_,key,value)saved=value;return true end,GetString=function()return saved end}
local T=require("src/ui/trace")
T.mark("window list: PrettyUI.Window.new")
assert(saved==require("src/core/vars").version.." | window list: PrettyUI.Window.new")
local original=print
print=function(value)printed=value end
T.reportPrevious()
print=original
assert(printed:find(saved,1,true) and printed:find("not a crash diagnosis",1,true))
PersistentDB=nil
assert(pcall(T.mark,"monitor: ready"))
assert(pcall(T.reportPrevious))
print("UI checkpoints passed: saved stage, previous-stage report and unavailable storage")
