local P=require('src/ui/window_position')
local values,writes={},0
PersistentDB={GetString=function(_,k)return values[k]end,SetString=function(_,k,v)writes=writes+1;values[k]=v;return true end}
local area={width=1488,height=997}
local w={root={x=700,y=200},positionKind='monitor'}
for _=1,26 do P.tick(w)end
assert(writes==1)
for _=1,100 do P.tick(w)end
assert(writes==1,'Unchanged position must not repeatedly write storage')
local x,y=P.load('monitor',area,340,440,24,100)
assert(x==700 and y==200,'Position survives window recreation')
w.root.x=1000;P.save(w)
x,y=P.load('monitor',{width=720,height=500},340,440,24,100)
assert(x==380 and y==60,'Restored position stays on a smaller screen')
x,y=P.load('editor',area,1080,880,204,58)
assert(x==204 and y==58,'Editor placement is separate')
values[P.key..'monitor']='nan,garbage'
x,y=P.load('monitor',area,340,440,24,100)
assert(x==24 and y==100,'Invalid saved coordinates use defaults')
PersistentDB=nil
assert(pcall(P.save,w))
x,y=P.load('monitor',area,340,440,24,100)
assert(x==24 and y==100)
print('Window positions passed: persistence, bounded writes, smaller screens, invalid data and missing storage')
