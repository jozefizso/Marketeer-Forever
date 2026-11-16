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
local function chattyAPI()
  local api=Chattynator and Chattynator.API
  if api and type(api.GetWindowsAndTabs)=='function' and type(api.AddMessageToWindowAndTab)=='function' then return api end
end
local function chattySettings()
  if type(MarketeerForeverCoreDB)~='table' then return nil end
  local character=UnitGUID and UnitGUID('player');if type(character)~='string' or character=='' then return nil end
  local db=MarketeerForeverCoreDB;db.auctionChattyTabs=db.auctionChattyTabs or {};db.auctionChattyTabs[character]=db.auctionChattyTabs[character] or {}
  return db.auctionChattyTabs[character]
end
local function tabKey(window,name) return tostring(window)..'\031'..name end
local function deliver(text)
  if type(text)~='string' or text=='' or (issecretvalue and issecretvalue(text)) then return end
  local db=windows();if not db then return end
  local color=ChatTypeInfo and ChatTypeInfo.SYSTEM or {r=1,g=1,b=0}
  local api=chattyAPI()
  if api then
    local settings=chattySettings();local ok,tabs=pcall(api.GetWindowsAndTabs)
    if settings and ok and type(tabs)=='table' then for window,list in ipairs(tabs) do for index,name in ipairs(list) do
      if type(name)=='string' and settings[tabKey(window,name)] then pcall(function()api.AddMessageToWindowAndTab(window,index,text,color.r or 1,color.g or 1,color.b or 0)end) end
    end end end
    return
  end
  for id,enabled in pairs(db) do
    local frame=enabled and _G['ChatFrame'..id]
    if frame and frame.AddMessage and not hasSystem(frame) then frame:AddMessage(text,color.r or 1,color.g or 1,color.b or 0) end
  end
end
local settingsFrame,settingsContent,settingsNote,settingsRows
function MarketeerForeverCore.ShowAuctionChatSettings()
  if not settingsFrame then
    settingsFrame=CreateFrame('Frame','MarketeerAuctionChatSettings',UIParent,'BackdropTemplate');settingsFrame:SetSize(470,390);settingsFrame:SetPoint('CENTER');settingsFrame:SetFrameStrata('FULLSCREEN_DIALOG');settingsFrame:SetClampedToScreen(true);settingsFrame:EnableMouse(true)
    settingsFrame:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1});settingsFrame:SetBackdropColor(.055,.075,.065,.98);settingsFrame:SetBackdropBorderColor(.25,.48,.34,1)
    MarketeerForeverCore.RegisterEscapeFrame('MarketeerAuctionChatSettings')
    local title=settingsFrame:CreateFontString(nil,'OVERLAY','GameFontNormal');title:SetPoint('TOPLEFT',16,-16);title:SetText('AUCTION CHAT  |  CHATTYNATOR')
    local close=CreateFrame('Button',nil,settingsFrame,'UIPanelButtonTemplate');close:SetSize(26,22);close:SetPoint('TOPRIGHT',-8,-8);close:SetText('X');close:SetScript('OnClick',function()settingsFrame:Hide()end)
    settingsNote=settingsFrame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');settingsNote:SetPoint('TOPLEFT',16,-44);settingsNote:SetWidth(430);settingsNote:SetJustifyH('LEFT');settingsNote:SetWordWrap(true)
    local scroll=CreateFrame('ScrollFrame',nil,settingsFrame,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',14,-105);scroll:SetPoint('BOTTOMRIGHT',-32,12)
    settingsContent=CreateFrame('Frame',nil,scroll);settingsContent:SetSize(420,1);scroll:SetScrollChild(settingsContent);settingsRows={}
  end
  local api=chattyAPI();local ok,tabs=false,nil;if api then ok,tabs=pcall(api.GetWindowsAndTabs) end
  local db=chattySettings();local count=0
  for _,row in ipairs(settingsRows) do row:Hide() end
  if not api or not ok or type(tabs)~='table' then settingsNote:SetText('Chattynator is not available. Install and enable it, then reload. For Blizzard chat, use the Auction House checkbox in that chat tab’s Other settings.')
  else
    settingsNote:SetText('Select the Chattynator tabs that should receive auction notifications. In each tab’s Chattynator filters, allow Marketeer under Addons. Turn off System messages there to avoid duplicates.')
    for window,list in ipairs(tabs) do for _,name in ipairs(list) do if type(name)=='string' then
      count=count+1;local row=settingsRows[count]
      if not row then
        row=CreateFrame('CheckButton',nil,settingsContent,'UICheckButtonTemplate');row:SetSize(26,26);row:SetPoint('TOPLEFT',0,-(count-1)*28)
        row.caption=row:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');row.caption:SetPoint('LEFT',row,'RIGHT',4,0);row.caption:SetWidth(370);row.caption:SetJustifyH('LEFT');settingsRows[count]=row
        row:SetScript('OnClick',function(self)local saved=chattySettings();if saved and self.key then saved[self.key]=self:GetChecked() and true or nil end end)
      end
      row.key=tabKey(window,name);row.caption:SetText('Window '..window..'  |  '..name);row:SetChecked(db and db[row.key]==true);row:Show()
    end end end
    if count==0 then settingsNote:SetText('No Chattynator tabs were found. Create a chat tab first, then reopen these settings.') end
  end
  settingsContent:SetHeight(math.max(1,count*28));settingsFrame:Show()
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
