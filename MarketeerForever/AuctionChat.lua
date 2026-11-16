-- Route auction-specific client notifications to opted-in chat windows.
-- Blizzard's original system messages and other chat settings remain untouched.
local function windows()
  if type(MarketeerForeverCoreDB)~='table' then return nil end
  local character=UnitGUID and UnitGUID('player')
  if type(character)~='string' or character=='' then return nil end
  local db=MarketeerForeverCoreDB
  db.auctionChatWindows=db.auctionChatWindows or {}
  db.auctionChatWindows[character]=db.auctionChatWindows[character] or {}
  return db.auctionChatWindows[character]
end
local function currentID()
  local frame=FCF_GetCurrentChatFrame and FCF_GetCurrentChatFrame()
  local id=frame and frame.GetID and frame:GetID()
  return type(id)=='number' and id>0 and id or nil
end
local function selected()
  local db,id=windows(),currentID()
  return db and id and db[id]==true or false
end
local function setSelected(_,checked)
  local db,id=windows(),currentID()
  if db and id then db[id]=checked and true or nil end
end
local entry={text='Auction House',type='SYSTEM',checked=selected,func=setSelected,
  tooltip='Show auction notifications in this chat tab without enabling all system messages. Tabs that already show system messages keep the original notices.'}
local function installSetting()
  local list=CHAT_CONFIG_OTHER_SYSTEM
  if type(list)~='table' then return end
  for _,value in ipairs(list) do if value==entry then return end end
  list[#list+1]=entry
  -- ChatConfig can be load-on-demand or may have already created its controls.
  if ChatConfigOtherSettingsSystem and ChatConfigOtherSettingsSystem.checkBoxTable and type(ChatConfig_CreateCheckboxes)=='function' then
    ChatConfig_CreateCheckboxes(ChatConfigOtherSettingsSystem,list,'ChatConfigCheckboxWithSwatchTemplate',OTHER)
    if type(ChatConfig_UpdateChatSettings)=='function' then ChatConfig_UpdateChatSettings() end
  end
end
local function hasSystem(frame)
  for _,group in pairs(frame.messageTypeList or {}) do if group=='SYSTEM' then return true end end
  return false
end
local function deliver(text)
  if type(text)~='string' or text=='' or (issecretvalue and issecretvalue(text)) then return end
  local db=windows();if not db then return end
  local color=ChatTypeInfo and ChatTypeInfo.SYSTEM or {r=1,g=1,b=0}
  for id,enabled in pairs(db) do
    local frame=enabled and _G['ChatFrame'..id]
    if frame and frame.AddMessage and not hasSystem(frame) then frame:AddMessage(text,color.r or 1,color.g or 1,color.b or 0) end
  end
end
local function formatted(notification,arg)
  if ChatFrameUtil and type(ChatFrameUtil.GetAuctionHouseNotificationText)=='function' then
    local ok,text=pcall(ChatFrameUtil.GetAuctionHouseNotificationText,notification,arg)
    if ok and type(text)=='string' and text~='' then return text end
  end
  local e=Enum and Enum.AuctionHouseNotification or {}
  local formatString=notification==e.AuctionSold and ERR_AUCTION_SOLD_S or notification==e.AuctionWon and ERR_AUCTION_WON_S or notification==e.AuctionOutbid and ERR_AUCTION_OUTBID_S or notification==e.AuctionExpired and ERR_AUCTION_EXPIRED_S or notification==e.BidPlaced and ERR_AUCTION_BID_PLACED or notification==e.AuctionRemoved and ERR_AUCTION_REMOVED
  if type(formatString)=='string' then local ok,text=pcall(string.format,formatString,arg or '');if ok then return text end end
end
local listener=CreateFrame('Frame')
for _,event in ipairs({'ADDON_LOADED','PLAYER_LOGIN','AUCTION_HOUSE_SHOW_NOTIFICATION','AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION','AUCTION_HOUSE_SHOW_COMMODITY_WON_NOTIFICATION'}) do pcall(listener.RegisterEvent,listener,event) end
listener:SetScript('OnEvent',function(_,event,a,b)
  if event=='ADDON_LOADED' or event=='PLAYER_LOGIN' then installSetting()
  elseif event=='AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION' then deliver(formatted(a,b))
  elseif event=='AUCTION_HOUSE_SHOW_NOTIFICATION' then deliver(formatted(a))
  elseif event=='AUCTION_HOUSE_SHOW_COMMODITY_WON_NOTIFICATION' then
    local name=type(a)=='string' and a or nil
    if name then local e=Enum and Enum.AuctionHouseNotification;local text=e and formatted(e.AuctionWon,name);deliver(text and (type(b)=='number' and b>1 and (text..' x'..b) or text)) end
  end
end)
