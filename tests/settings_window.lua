-- Cog has a minimal native button; ribbon and monitor use independent windows.
local callbacks={};local nativeButtons={}
Event=setmetatable({}, {__index=function(t,name)
 local event={Subscribe=function(_,fn)callbacks[name]=fn end,Unsubscribe=function()end}
 rawset(t,name,event);return event
end})
PersistentDB={GetBool=function()return nil end,GetString=function()return nil end,SetBool=function()return true end,SetString=function()return true end}
local area={width=1488,height=997}
local frame={hidden=false};local parent={width=568,height=296,parent=frame}
ui={Interfaces={GetComponent=function()return area end},Hook={ONBUTTONPRESSED=1},
 Text={new=function(actual)assert(actual==parent);return {SetPos=function()end,SetSize=function()end}end},
 Button={new=function(actual)
 assert(actual==parent)
 local b={SetPos=function()end,SetSize=function()end,Subscribe=function(self,_,fn)self.press=fn end}
 nativeButtons[#nativeButtons+1]=b;return b
end}}
id={Component={TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP=1},Font={MUSEO_SANS_13PT_REGULAR=28},StyleSheet={BUTTON_DEFAULT=1}}
Player={IsAvailable=function()return false end}
local mounts=0;local windows={}
prettyui={Window={new=function(actual,opts)
 assert(actual==area and opts.width==340 and opts.height==254)
 local w={content={width=308,height=194},Show=function()end}
 function w:Destroy()self.destroyed=true end
 windows[#windows+1]=w;return w
end}}
local dashboard={}
function dashboard.mount()mounts=mounts+1;dashboard.context={}end
function dashboard.destroy()dashboard.context=nil end
function dashboard.tick()end
package.loaded['src/ui/dashboard']=dashboard
dofile('main.lua')
assert(mounts==0 and #windows==0)
callbacks.SettingsLayerReady({component=parent})
assert(mounts==0 and #windows==0 and not frame.hidden,'Cog cannot create floating windows during native setup')
nativeButtons[1].press()
assert(mounts==0 and #windows==0,"Native click must return before window creation")
callbacks.Logic({logicTick=1})
assert(mounts==1 and #windows==1)
callbacks.ContentLayerReady({component=parent})
assert(mounts==1 and #windows==1,'Ribbon queues without creating windows')
callbacks.Logic({logicTick=2})
assert(mounts==1 and #windows==1,'Queued ribbon request reuses monitor')
Player={IsAvailable=function()return false end}
frame.hidden=true
for i=1,1000 do callbacks.Logic({logicTick=i})end
assert(#windows==1 and not windows[1].destroyed,'Closing native settings never creates or destroys floating windows')
dashboard.destroy() -- Monitor close clears its controls but retains the hidden host.
callbacks.ContentLayerReady({component=parent})
callbacks.Logic({logicTick=1001})
assert(mounts==2 and #windows==1,'Reopening restores monitor content in the existing host')
PluginShutdown();assert(windows[1].destroyed)
print('Settings integration passed: minimal cog, monitor button/ribbon, no close-triggered window work and cleanup')
