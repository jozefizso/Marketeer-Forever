-- Experimental shared-channel test. No ordinary chat messages are sent.
local core=MarketeerForeverCore
local prefix,channel="MktBeta1","MarketeerBetaSync"
local pending,peerSeen,sending=false,false,false
local scanAt,scanMarket,scanItems,nonce
local function say(s) print("|cff55ee99Marketeer beta:|r "..s) end
local function now() return GetServerTime and GetServerTime() or time() end
local function market() return core and core.Market and core.Market() end
local function channelID() local id=GetChannelName and GetChannelName(channel);return type(id)=="number" and id>0 and id or nil end
local function send(message)
  local id=channelID()
  if not id or not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return false end
  local ok,result=pcall(C_ChatInfo.SendAddonMessage,prefix,message,"CHANNEL",id)
  return ok and (result==nil or result==0 or result==true)
end
local function clearPending(message)
  pending=false;peerSeen=false;scanItems=nil
  if message then say(message) end
end
local function transmit()
  if not pending or not peerSeen or not scanItems or sending then return end
  sending=true;local items=scanItems;local index,packets=1,0
  local function step()
    if not pending or market()~=scanMarket then sending=false;clearPending("Sync stopped: market changed.");return end
    if index>#items then sending=false;clearPending("Sent "..#items.." prices in "..packets.." packets. Receiving players can see shared prices on item tooltips.");return end
    local header="D|"..scanMarket.."|"..scanAt.."|";local parts={};local length=#header
    while index<=#items do
      local entry=items[index];local extra=#entry+(#parts>0 and 1 or 0)
      if length+extra>230 then break end
      parts[#parts+1]=entry;length=length+extra;index=index+1
    end
    if #parts==0 or not send(header..table.concat(parts,",")) then sending=false;clearPending("Channel send failed. Forever may block shared addon channels.");return end
    packets=packets+1;C_Timer.After(.25,step)
  end
  step()
end
local function begin()
  if pending then say("A scan and sync is already in progress.");return end
  local m=market();if not m then say("Could not identify your market group.");return end
  if not channelID() then say("Shared test channel is unavailable. Try again after login.");return end
  pending=true;peerSeen=false;scanMarket=m;scanAt=nil;scanItems=nil
  nonce=tostring(now())..tostring(math.random(1000,9999))
  local ok,err=core.Scan()
  if not ok then clearPending("Scan could not start: "..tostring(err));return end
  say("Scanning the auction house and testing the shared addon channel.")
  if not send("P|"..m.."|"..nonce) then say("Channel send was rejected; the local scan will still finish.") end
  C_Timer.After(15,function()
    if pending and not peerSeen then clearPending("No beta peer replied. Server-wide communication is not confirmed; no prices were shared.") end
  end)
end
core.Subscribe(function(event)
  if not pending then return end
  if event=="failed" then clearPending("Scan failed; no prices were shared.");return end
  if event~="complete" then return end
  local book=MarketeerForeverCoreDB and MarketeerForeverCoreDB.prices and MarketeerForeverCoreDB.prices[scanMarket]
  if not book or type(book.items)~="table" then clearPending("No completed scan was available.");return end
  scanAt=book.observed;scanItems={}
  for id,item in pairs(book.items) do
    if type(id)=="number" and type(item)=="table" and not item.carried and type(item.price)=="number" and item.price>0 and item.price<=1000000000000 then
      scanItems[#scanItems+1]=math.floor(id)..":"..math.floor(item.price)
    end
  end
  table.sort(scanItems)
  if #scanItems>3000 then while #scanItems>3000 do table.remove(scanItems) end;say("Beta limit: sharing the first 3000 item IDs.") end
  say("Scan complete: "..#scanItems.." prices ready; "..(peerSeen and "peer found." or "waiting for a peer."))
  transmit()
end)
local function receive(message,sender)
  if type(message)~="string" or #message>255 or type(sender)~="string" then return end
  if UnitName and sender:match("^[^-]+")==(UnitName("player") or "") then return end
  local kind,m,rest=message:match("^([PAD])|([%w/%-]+)|(.+)$")
  if not kind or m~=market() then return end
  if kind=="P" then
    if rest:match("^%d%d%d%d%d%d%d%d%d%d%d%d%d%d$") then send("A|"..m.."|"..rest) end
  elseif kind=="A" then
    if pending and rest==nonce then peerSeen=true;say("A beta peer replied: "..sender..". Shared-channel delivery works for this test.");transmit() end
  elseif kind=="D" then
    local stamp,body=rest:match("^(%d+)|([%d:,]+)$");stamp=tonumber(stamp)
    if not stamp or stamp>now()+60 or now()-stamp>3600 then return end
    MarketeerSyncBetaDB=MarketeerSyncBetaDB or {};MarketeerSyncBetaDB.markets=MarketeerSyncBetaDB.markets or {}
    local saved=MarketeerSyncBetaDB.markets[m] or {};MarketeerSyncBetaDB.markets[m]=saved
    for id,price in body:gmatch("(%d+):(%d+)") do
      id,price=tonumber(id),tonumber(price)
      if id and id>0 and id<2147483648 and price and price>0 and price<=1000000000000 and (not saved[id] or stamp>saved[id].time) then saved[id]={price=price,time=stamp,sender=sender} end
    end
  end
end
local function addTooltip(tooltip,data)
  if not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
  local _,link=tooltip:GetItem();local id=(type(link)=="string" and tonumber(link:match("item:(%d+)"))) or (data and data.id)
  local m=market();local db=MarketeerSyncBetaDB and MarketeerSyncBetaDB.markets and MarketeerSyncBetaDB.markets[m];local row=db and db[id]
  if not row or now()-row.time>3600 then return end
  local value=GetCoinTextureString and GetCoinTextureString(row.price) or (row.price.."c")
  tooltip:AddLine("Beta shared AH / unit: "..value.." ("..math.floor((now()-row.time)/60).."m ago)",.35,1,.55);tooltip:Show()
end
if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,addTooltip)
elseif GameTooltip and GameTooltip.HookScript then GameTooltip:HookScript("OnTooltipSetItem",addTooltip) end
local hooked
local function setupButton()
  local panel=_G.MarketeerForeverMarketFlipPanel
  if not panel or not panel.GetChildren then return end
  for _,child in ipairs({panel:GetChildren()}) do
    if child.GetText and child:GetText()=="Scan now" then
      child:SetWidth(104);child:SetText("Scan & Sync");if child.GetFontString and child:GetFontString() then child:GetFontString():SetTextColor(.25,1,.4) end
      child:SetScript("OnClick",begin);hooked=true;return
    end
  end
end
local f=CreateFrame("Frame");f:RegisterEvent("PLAYER_LOGIN");f:RegisterEvent("CHAT_MSG_ADDON");f:RegisterEvent("AUCTION_HOUSE_SHOW")
f:SetScript("OnEvent",function(_,event,a,b,c,d)
  if event=="PLAYER_LOGIN" then
    MarketeerSyncBetaDB=MarketeerSyncBetaDB or {}
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(prefix) end
    if JoinTemporaryChannel then JoinTemporaryChannel(channel) end
    say("Experimental server-wide sync test enabled. Shared-channel delivery is not yet verified.")
  elseif event=="CHAT_MSG_ADDON" and a==prefix and c=="CHANNEL" then receive(b,d)
  elseif event=="AUCTION_HOUSE_SHOW" and not hooked then
    for i=1,10 do C_Timer.After(i*.5,function() if not hooked then setupButton() end end) end
  end
end)
