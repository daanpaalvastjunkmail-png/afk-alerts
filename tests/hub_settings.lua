local H=require('src/ui/hub_settings')
local opened=0;local buttons={};local children={}
local parent=setmetatable({width=568,height=296},{__index=function()error('No native parent access beyond size')end})
ui={Hook={ONBUTTONPRESSED=1},Text={new=function(actual)
 assert(actual==parent)
 local t={SetPos=function()end,SetSize=function()end};children[#children+1]=t;return t
end},Button={new=function(actual)
 assert(actual==parent)
 local b={SetPos=function()end,SetSize=function()end}
 function b:Subscribe(hook,fn)assert(hook==1);self.press=fn end
 buttons[#buttons+1]=b;children[#children+1]=b;return b
end}}
id={Font={MUSEO_SANS_13PT_REGULAR=28},StyleSheet={BUTTON_DEFAULT=1}}
prettyui=setmetatable({}, {__index=function()error('Native settings must not create PrettyUI controllers')end})
H.mount(parent,{},function()opened=opened+1 end)
assert(#children==2 and #buttons==1 and buttons[1].label=='Open alert monitor')
assert(opened==0,'Opening the cog never creates floating windows')
buttons[1].press();assert(opened==1)
assert(H.parent==nil and H.view==nil and H.pending==nil and H.tick==nil,'No native handles or deferred work retained')
H.destroy();assert(opened==1,'Cleanup cannot launch windows or touch client-owned components')
print('Hub settings passed: native children only, no visibility polling, no retained handles, no full-settings shortcut and no automatic opening on close')
