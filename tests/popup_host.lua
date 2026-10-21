local V=require('src/core/vars')
local H=require('src/host')
local area={width=1000,height=800}
local created,clicked=0,0
ui={Interfaces={GetComponent=function()return area end},Hook={ONCLICK=1},
 TextDataConfig={new=function()return {}end},AlignMode={CENTRE=1},Layer={new=function(parent)
  assert(parent==area);created=created+1
  local layer={SetPos=function()end,SetSize=function()end,MoveToFront=function()end,Destroy=function(self)self.destroyed=true end}
  function layer:Subscribe(hook,fn)assert(hook==1);self.callback=fn end
  return layer
 end}}
id={Component={TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP=1},Font={MUSEO_SANS_15PT_REGULAR=15}}
Vector4={new=function(...)return {...}end}
H.install()
H.canvas={AddText=function(_,x,y,w,h,text,cfg)
 assert(type(w)=='number' and h==28 and type(text)=='string' and cfg.font==15,'Canvas text must use the documented config overload')
end,Destroy=function()end}
assert(V.call('text',20,40,'Inventory full',0xFFFFFFFF,500))
assert(V.call('text',20,40,'Custom alert',0xFFFFFFFF))
V.call('popupInput',true,function()clicked=clicked+1 end)
assert(H.dismissLayer.clickthrough and H.dismissLayer.callback()==true and clicked==1,'Click listener must pass input through')
for i=1,100 do V.call('popupInput',true,function()end)end
assert(created==1,'Repeated alerts reuse one owned input layer')
V.call('popupInput',false,function()end);assert(H.dismissLayer.hidden)
H.destroy();assert(H.dismissLayer==nil)
print('Popup host passed: documented text signatures, transparent click listener, reuse and cleanup')
