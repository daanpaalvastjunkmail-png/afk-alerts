-- A visible grip backed by the resize handle owned by this PrettyUI window.
-- Keep PrettyUI's capture, interface-scale handling, bounds and teardown.
local G={size=28}
function G.update(window)
 if not window or not window.root or not window.resize then return end
 local resize=window.resize
 local handle=resize.handles and resize.handles.se
 if not handle or resize.dragState or window.root.hidden or resize.enabled==false then return end
 local root=window.root
 handle:SetPos(root.x+root.width-G.size,root.y+root.height-G.size)
 handle:SetSize(G.size,G.size)
end
function G.install(window)
 if not window or not window.root or not window.resize or not window.resize.handles or not window.resize.handles.se then return end
 -- PrettyUI refreshes its handles after moves and layout changes. Wrap only
 -- this window's controller so its normal refresh cannot shrink our grip.
 local resize=window.resize
 if not window.afkGripRefreshInstalled and type(resize._Refresh)=="function" then
  local refresh=resize._Refresh
  resize._Refresh=function(controller,...)
   refresh(controller,...)
   G.update(window)
  end
  window.afkGripRefreshInstalled=true
 end
 if not window.afkResizeGrip and ui and ui.Canvas and ui.Canvas.new then
  local canvas=ui.Canvas.new(window.root)
  canvas:SetPos(-G.size,-G.size,1,1);canvas:SetSize(G.size,G.size)
  canvas.clickthrough=true
  canvas:AddRectangle(4,4,24,24,0x29251DDD)
  for offset=0,12,6 do canvas:AddLine(8+offset,25,25,8+offset,2,0xD7BD7AFF)end
  window.afkResizeGrip=canvas
 end
 G.update(window)
end
return G
