-- Non-modal window bounds, native Hub isolation and cleanup.
local V=require('src/core/vars')
local W=require('src/ui/settings_host')
local screen={width=1488,height=997}
V.adapters.gameArea=function() return screen end
local windows={}
prettyui={Window={new=function(parent,opts)
 assert(parent==screen)
 local close={}
 function close:SetPos(x,y,anchor)self.x=x;self.y=y;self.anchor=anchor end
 function close:SetSize(w,h)self.width=w;self.height=h end
 local window={options=opts,content={width=opts.width-32,height=opts.height-60},closeButton=close}
 function window:SetSize(w,h) self.options.width=w; self.options.height=h; self.content.width=w-32; self.content.height=h-60 end
 function window:Show() self.shown=true end
 function window:Destroy() self.destroyed=true end
 function window:Close() opts.onClose(self) end
 windows[#windows+1]=window
 return window
end}}
local frame={headerText={content='AFK ALERTS Settings'},hidden=false,parent=screen,width=600,height=360}
local layer={parent=frame,width=568,height=296}
local closed=0
local content=W.prepare(layer,function() closed=closed+1 end)
assert(content==windows[1].content and windows[1].shown)
assert(windows[1].closeButton.width==28 and windows[1].closeButton.height==28 and windows[1].closeButton.x==-32,'Owned window close button is enlarged within its title-bar drag exclusion')
assert(windows[1].options.width==820 and windows[1].options.height==580,'Editor uses a compact default size')
assert(not frame.hidden and frame.width==600,'Never hide the native Hub window or its close controls')
frame.hidden=false
W.tick()
assert(not frame.hidden,'No per-tick native visibility suppression')
windows[1]:Close()
assert(closed==1 and not frame.hidden,'Closing our editor leaves native UI untouched')
W.prepare(layer)
assert(windows[1].destroyed and not frame.hidden,'Repeated ribbon open replaces the editor without native mutations')
frame.headerText.content='Another Plugin Settings'
assert(not W.tick() and frame.hidden==false,'Selecting another plugin must leave native Hub input alone')
assert(not windows[2].destroyed,'Our non-modal monitor remains independent of native plugin selection')
frame.headerText.content='AFK ALERTS Settings'
screen.width=720; screen.height=500
W.prepare(layer)
assert(windows[3].options.width==672 and windows[3].options.height==452,'Editor must fit a small screen')
W.restore()
assert(windows[3].destroyed and frame.hidden==false)
-- Never hide an unidentified ancestor, including Plugin Hub itself.
frame.headerText.content='Plugin Hub'
W.prepare(layer)
assert(not frame.hidden and W.state.frame==nil)
W.restore()
-- Compact monitor survives independent editors and resizes without replacement.
frame.headerText.content='AFK ALERTS Settings'
screen.width=1488; screen.height=997
local data=require('src/core/settings').defaults()
W.prepare(layer,nil,'list',data)
local compact=W.state.window
assert(compact.options.width==340 and compact.options.height==254)
assert(compact.options.resizable and compact.options.minWidth==280)
local count=#windows
W.setMode('list',data)
assert(#windows==count and W.state.window==compact,'Unchanged monitor refresh must preserve its window/position')
W.setMode('edit',data)
assert(not compact.destroyed and W.state.window==compact and W.state.editorWindow.options.width==820,'Monitor survives editing')
local editor=W.state.editorWindow
W.closeEditor(); assert(editor.destroyed and not compact.destroyed)
W.setMode('list',data)
assert(W.state.window.options.width==340,'Back returns to the compact list')
for i=1,8 do require('src/core/settings').add(data,'health') end
W.setMode('list',data)
assert(W.state.window.options.height==440,'Long lists remain compact and scroll')
compact:SetSize(500,300);W.tick()
W.setMode('list',data)
assert(compact.options.width==500 and compact.options.height==300,'Automatic list sizing must not undo an interactive resize')
W.restore()
-- Failed creation must leave the native shell available.
frame.headerText.content='AFK ALERTS Settings'
prettyui.Window.new=function() error('Window creation failed') end
assert(not pcall(W.prepare,layer))
assert(frame.hidden==false and W.state==nil)
local strictLayer=setmetatable({}, {__index=function()error('Native Hub properties must not be inspected')end,__newindex=function()error('Native Hub properties must not be changed')end})
prettyui.Window.new=function(_,opts)
 return {content={width=opts.width-32,height=opts.height-60},Show=function()end,Destroy=function()end}
end
assert(pcall(W.prepare,strictLayer,nil,'list',data),'Opening from the ribbon must not inspect or mutate native ancestors')
W.tick();W.restore()
print('Settings host passed: large editor, screen bounds, shell isolation, reopening and cleanup')
