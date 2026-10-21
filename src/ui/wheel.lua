-- Raw native controls bypass PrettyUI's flow options. Forward their wheel input
-- explicitly to the owning scroll host, leaving all click/drag handlers alone.
local W={}
function W.bind(component,owner)
 if not component or not component.Subscribe or not owner or type(owner._onScrollWheel)~='function' then return end
 if not ui or not ui.Hook or not ui.Hook.ONSCROLLWHEEL then return end
 component:Subscribe(ui.Hook.ONSCROLLWHEEL,'afk_alerts_wheel',function(control,delta)
  return owner._onScrollWheel(control,delta)
 end)
end
function W.forward(owner)
 return function(component,delta)
  if owner and type(owner._onScrollWheel)=='function' then return owner._onScrollWheel(component,delta)end
  return true
 end
end
return W
