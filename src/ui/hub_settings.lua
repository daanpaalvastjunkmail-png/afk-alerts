-- Use native children only in the client-owned settings layer. No PrettyUI
-- controllers, saved native handles, visibility polling or close-triggered work.
local V=require("src/core/vars")
local C={}
function C.destroy()
 -- The client owns and clears these native children with its settings layer.
end
function C.mount(parent,_,openMonitor)
 local text=ui.Text.new(parent)
 text:SetPos(12,12)
 text:SetSize(math.max(100,parent.width-24),80)
 text.font=id.Font.MUSEO_SANS_13PT_REGULAR
 text.content="Open the alert monitor below. Then close this Plugin Hub settings panel with its X before using Settings, Edit or Add in the monitor. Closing this panel never opens another window automatically."
 text.clickthrough=true
 local button=ui.Button.new(parent)
 button:SetPos(12,104);button:SetSize(200,30)
 button.stylesheetID=id.StyleSheet.BUTTON_DEFAULT
 button.label="Open alert monitor"
 button:Subscribe(ui.Hook.ONBUTTONPRESSED,function()V.safe(openMonitor)end)
end
return C
