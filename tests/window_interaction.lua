local G=require('src/ui/window_grip')
local Wheel=require('src/ui/wheel')
local canvases={}
ui={Hook={ONSCROLLWHEEL=4},Canvas={new=function(parent)
 local c={parent=parent,lines={}}
 function c:SetPos(x,y,xa,ya)self.x=x;self.y=y;self.xa=xa;self.ya=ya end
 function c:SetSize(w,h)self.width=w;self.height=h end
 function c:AddRectangle(...)self.rectangle={...}end
 function c:AddLine(...)self.lines[#self.lines+1]={...}end
 canvases[#canvases+1]=c;return c
end}}
local handle={}
function handle:SetPos(x,y)self.x=x;self.y=y end
function handle:SetSize(w,h)self.width=w;self.height=h end
local window={root={x=50,y=70,width=340,height=440},resize={handles={se=handle},enabled=true}}
function window.resize:_Refresh()handle:SetSize(10,10)end
G.install(window)
window.resize:_Refresh(false)
assert(handle.width==28,'Native layout refresh keeps the larger grip')
assert(handle.x==362 and handle.y==482 and handle.width==28 and handle.height==28,'Whole visible grip is a resize hit area')
assert(#canvases==1 and canvases[1].clickthrough and canvases[1].parent==window.root and #canvases[1].lines==3,'Visible grip belongs to the window and leaves input to the resize handle')
window.root.width=500;window.root.height=600;G.update(window)
assert(handle.x==522 and handle.y==642,'Grip follows resized geometry')
window.resize.dragState={captureExpanded=true};handle.width=1000;G.update(window)
assert(handle.width==1000,'Do not collapse the library drag capture')
window.resize.dragState=nil;G.update(window);assert(handle.width==28)
window.root.hidden=true;handle.width=0;G.update(window);assert(handle.width==0,'Do not reveal a hidden window handle')
G.install({});G.update(nil)
local calls={}
local owner={_onScrollWheel=function(component,delta)calls[#calls+1]={component,delta};return false end}
local raw={}
function raw:Subscribe(hook,id,fn)self.hook=hook;self.hookID=id;self.callback=fn end
Wheel.bind(raw,owner)
assert(raw.hook==4 and raw.callback(raw,2)==false and calls[1][1]==raw and calls[1][2]==2,'Raw slider/canvas wheels route once to the scroll host')
assert(Wheel.forward(owner)(raw,-3)==false and calls[2][2]==-3,'Non-scrolling child views forward both wheel directions')
assert(Wheel.forward(nil)(raw,1)==true,'No owner leaves propagation untouched')
Wheel.bind({},owner);Wheel.bind(raw,{})
print('Window interaction passed: larger resize grip, native drag-capture preservation, hidden windows and mouse-wheel forwarding')
