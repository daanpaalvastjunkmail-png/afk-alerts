local M=require('src/visual')
local V=require('src/core/vars')
local S=require('src/core/settings')
local d=S.defaults();local key,c=S.add(d,'health');c.visuals={circle=true};c.duration=10
local circles={}
V.adapters.gameArea=function()return {width=1000,height=800}end
V.adapters.circle=function(...)circles[#circles+1]={...}end
M.emit(key,c,{value=10},0)
M.rows={};M.draw(d,0.1)
assert(#circles==0,'No circle appears at a guessed cursor/HUD position while the monitor is closed')
M.rows[key]={xyGlobal={x=20,y=40},width=300,height=60}
M.draw(d,0.1)
assert(#circles==1 and circles[1][1]==170 and circles[1][2]==70,'Circle uses the actual monitor row')
M.destroy()
print('Monitor circles passed: actual row coordinates only, no unsupported HUD fallback')
