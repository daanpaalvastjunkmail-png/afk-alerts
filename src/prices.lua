-- Official GE guide-price lookups and calculated high-alchemy values.
-- Unknown prices remain unknown; they must never be substituted with zero.
local V=require("src/core/vars")
local P={cache={},queue={},queued={},failures={},failureMessages={},detailPending={},active=nil,nextRequest=0,running=true,time=0}
local MAX_SAFE=9007199254740991
local function valid(n) return V.finite(n) and n>=0 and n<=MAX_SAFE end
function P.parseGraph(body)
 if type(body)~="string" or #body>2000000 then return nil end
 local daily=body:match('"daily"%s*:%s*{([^{}]*)}')
 if not daily or daily:match('^%s*$') then return nil end
 local stamp,price=-1,nil
 for field in daily:gmatch('[^,]+') do
  local key,value=field:match('^%s*"(%d+)"%s*:%s*(%d+)%s*$')
  if not key then return nil end
  local t,n=tonumber(key),tonumber(value)
  if not valid(t) or not valid(n) then return nil end
  if t>stamp then stamp,price=t,n end
 end
 return price,stamp
end
-- The catalogue endpoint can abbreviate guide prices (for example 75.1k).
-- Keep that precision flag so the tracker never presents it as exact.
function P.parseDetail(body,item)
 if type(body)~="string" or #body>2000000 or not body:match('^%s*{') or not body:match('}%s*$') then return nil end
 local found=tonumber(body:match('"id"%s*:%s*(%d+)%s*[,}]'))
 if found~=item then return nil end
 local current=body:match('"current"%s*:%s*{([^{}]*)}')
 if not current then return nil end
 local raw=current:match('"price"%s*:%s*"([^"\\]*)"')
 if not raw then
  local n=tonumber(current:match('"price"%s*:%s*(%d+)%s*[,}]?%s*$'))
  if valid(n) and n%1==0 then return n,false end
  return nil
 end
 raw=raw:match('^%s*(.-)%s*$'):lower()
 local amount,suffix=raw:match('^(%d+%.?%d*)([kmb])$')
 if amount then
  if not amount:match("^%d+$") and not amount:match("^%d+%.%d+$") then return nil end
  local n=tonumber(amount)*({k=1000,m=1000000,b=1000000000})[suffix]
  if valid(n) and n%1==0 then return n,true end
  return nil
 end
 if raw:find(',',1,true) then
  local first,rest=raw:match('^(%d+),(.*)$')
  if not first or #first>3 then return nil end
  for group in (rest..','):gmatch('(.-),') do if not group:match('^%d%d%d$') then return nil end end
  raw=raw:gsub(',','')
 end
 if not raw:match('^%d+$') then return nil end
 local n=tonumber(raw)
 if valid(n) and n%1==0 then return n,false end
end
function P.highAlch(base)
 if not valid(base) then return nil end
 base=math.floor(base)
 -- Integer arithmetic avoids floating-point rounding at 60%.
 return (base//5)*3+((base%5)*3)//5
end
local function permitted()
 return V.permission("httpAccess")
end
function P.get(item,metric,entry)
 if metric=="high_alch" then
  local value=P.highAlch(entry and entry.baseCost)
  V.status.prices=value~=nil and "Calculated High Alch available" or "Item base value unavailable"
  return value
 end
 if metric~="ge" or not valid(item) or item%1~=0 then return nil end
 if item==995 then return 1 end -- One coin is worth one coin.
 if entry and entry.tradeable==false then V.status.prices="GE unavailable for an untradeable item"; return nil,V.status.prices end
 if not permitted() then V.status.prices="GE permission required: Settings > General > Manage permissions"; return nil,V.status.prices end
 local cached=P.cache[item]
 if cached and P.time-cached.loaded<3600 then return cached.price,cached.approximate end
 if P.failures[item] and P.time<P.failures[item] then V.status.prices=P.failureMessages[item] or "GE lookup failed; waiting before retry"; return nil,V.status.prices end
 if not P.queued[item] then
  if #P.queue>=100 then V.status.prices="GE request queue is full"; return nil,V.status.prices end
  P.queued[item]=true; P.queue[#P.queue+1]=item
 end
 V.status.prices=P.detailPending[item] and "Loading GE item-price fallback" or "Loading official GE guide price"
 return nil,V.status.prices
end
local function failed(item,message)
 P.failures[item]=P.time+120
 P.failureMessages[item]=message;P.detailPending[item]=nil
 V.status.prices=message
 V.report("prices",message.." (item "..item..")")
end
local function enqueueFallback(item,message)
 if P.detailPending[item] then failed(item,message);return end
 P.detailPending[item]=true
 P.queued[item]=true;table.insert(P.queue,1,item)
 V.status.prices="Loading GE item-price fallback"
end
local function testStatus(message)
 V.status.geTest=message
 return message
end
function P.permissionStatus()
 return V.permissionStatus("httpAccess","HTTP")
end
function P.testConnection()
 if not permitted() then
  P.probe=nil
  return testStatus(P.permissionStatus()..". Use Request HTTP access or Plugin Hub > AFK ALERTS > padlock, then test again.")
 end
 if P.probe then return V.status.geTest end
 -- An explicit test bypasses the cached/backoff result for this test item only.
 P.cache[4151]=nil;P.failures[4151]=nil;P.failureMessages[4151]=nil
 P.probe={started=P.time}
 P.get(4151,"ge",{tradeable=true})
 return testStatus("HTTP access enabled. Testing GE connection with Abyssal whip (4151)...")
end
function P.allowRequests()
 -- Only called by an explicit button. The client owns the consent decision.
 P.enablePending=true
 return testStatus("Requesting optional HTTP access for GE prices. Confirm your choice in the client.")
end
local function updatePermissionAndTest(now)
 if P.enablePending then
  P.enablePending=nil
  if not permitted() then
   V.requestPermissions()
  end
  P.permissionDeadline=now+60
 end
 local requested=V.flushPermissionRequest()
 if requested==false and P.permissionDeadline then
  P.permissionDeadline=nil;testStatus(V.status.permissions)
 end
 if P.permissionDeadline then
  if permitted() then
   P.permissionDeadline=nil;P.testConnection()
  elseif now>=P.permissionDeadline then
   P.permissionDeadline=nil
   testStatus("HTTP access is still disabled. Check Plugin Hub > AFK ALERTS > padlock, then click Test GE connection after granting access.")
  end
 end
 if P.probe then
  if not permitted() then P.probe=nil;testStatus("GE test stopped: HTTP access disabled");return end
  local cached=P.cache[4151]
  if cached and cached.loaded>=P.probe.started then
   P.probe=nil
   testStatus("GE connection OK. Abyssal whip: "..(cached.approximate and "approx. " or "")..string.format("%.0f",cached.price).." gp. Waiting for a matching owned ground-item drop.")
  elseif P.failureMessages[4151] then
   P.probe=nil;testStatus("GE connection test failed: "..P.failureMessages[4151])
  elseif now-P.probe.started>=60 then
   P.probe=nil;testStatus("GE connection test did not finish within 60 seconds. Check Settings > Developer > Prices.")
  end
 end
end
function P.tick(now)
 if not V.finite(now) then return end
 if now<P.time then
  -- These deadlines use elapsed client time, not wall time. Preserve their
  -- remaining delay when the client Logic clock restarts.
  local delta=now-P.time
  P.nextRequest=P.nextRequest+delta
  for _,cached in pairs(P.cache) do cached.loaded=cached.loaded+delta end
  for item,deadline in pairs(P.failures) do P.failures[item]=deadline+delta end
  if P.active then P.active.started=P.active.started+delta end
  if P.probe then P.probe.started=P.probe.started+delta end
  if P.permissionDeadline then P.permissionDeadline=P.permissionDeadline+delta end
 end
 P.time=now
 if not P.running then return end
 updatePermissionAndTest(now)
 if not permitted() then
  local active=P.active;P.active=nil
  P.queue={};P.queued={};P.detailPending={}
  if active then V.safe(function()active.request:Cancel()end)end
  V.status.prices="GE permission is not enabled"
  return
 end
 local active=P.active
 if active then
  if now-active.started>=10 then
   P.active=nil; P.queued[active.item]=nil
   V.safe(function() active.request:Cancel() end)
   if active.detail then failed(active.item,"GE request timed out")
   else enqueueFallback(active.item,"GE request timed out") end
  end
  return
 end
 if #P.queue==0 or now<P.nextRequest then return end
 local item=table.remove(P.queue,1)
 local detail=P.detailPending[item]==true
 P.nextRequest=now+2
 local request
 local function failure(message)
  if detail then P.detailPending[item]=nil;failed(item,message)
  else enqueueFallback(item,message) end
 end
 local ok,err=pcall(function()
  local path=detail and ("/m=itemdb_rs/api/catalogue/detail.json?item="..item) or ("/m=itemdb_rs/api/graph/"..item..".json")
  request=HTTPRequest.new(Plugin.urls.ge,path)
  local record={item=item,request=request,started=now,detail=detail}
  P.active=record
  request:Get(function(result)
   V.safe(function()
    if not P.running or P.active~=record or not permitted() then return end
    P.active=nil; P.queued[item]=nil
    if result.successful and result.responseCode==200 then
     local price,stamp,approximate
     if detail then price,approximate=P.parseDetail(result.data,item)
     else price,stamp=P.parseGraph(result.data) end
     if price~=nil then
      P.cache[item]={price=price,stamp=stamp,loaded=P.time,approximate=approximate==true}
      P.failures[item]=nil;P.failureMessages[item]=nil;P.detailPending[item]=nil
      V.status.prices=approximate and "Rounded GE guide price cached" or "Official GE guide price cached (up to 1 hour)"
     else failure("GE returned an unsupported or empty price response") end
    else
     local message="GE request failed: HTTP "..tostring(result.responseCode)
     if result.timedOut then message="GE request timed out"
     elseif result.failed then message=message.."; error "..tostring(result.errorCode)..": "..tostring(result.errorInfo) end
     failure(message)
    end
   end)
  end)
 end)
 if not ok then
  P.active=nil; P.queued[item]=nil;failure("GE request error: "..tostring(err))
 end
end
function P.install()
 P.running=true
 V.adapters.price=P.get
end
function P.stop()
 P.running=false
 V.permissionRequestPending=nil
 P.enablePending=nil;P.permissionDeadline=nil;P.probe=nil
 local active=P.active; P.active=nil; P.queue={}; P.queued={}; P.detailPending={}
 if active then V.safe(function() active.request:Cancel() end) end
end
return P
