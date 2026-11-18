-- The announcement appears only after the new companion has usable data.
local core=MarketeerForeverCore
local dialog,body,first,nextButton,back,confirm
local function showAnnouncement()
  if MarketeerForeverCoreDB and MarketeerForeverCoreDB.dataCompanionAcknowledged then return end
  if dialog and dialog:IsShown() then return end
  if _G.MarketeerSnapshotCompanion~=1 then return end
  if not core.Market or not core.LoadMarketSnapshot then return end
  local market=core.Market();if not market then return end
  core.LoadMarketSnapshot()
  local data=_G.MarketeerSnapshotMarketData
  local row=type(data)=='table' and data.schemaVersion==1 and data.periodHours==24 and type(data.tables)=='table' and data.tables[market]
  local now=(GetServerTime and GetServerTime()) or time()
  if type(row)~='table' or type(row.text)~='string' or row.text=='' or type(row.count)~='number' or row.count<=0 or type(row.updated)~='number' or row.updated<=0 or row.updated>now+300 or now-row.updated>48*3600 then return end
  local line=row.text:match('[^\n]+')
  if not line or not line:match('^%d+:%d*:%d*:%d*:%d*:%d*:%d*:%d*:%d*$') then return end
  if not dialog then
    dialog=CreateFrame('Frame','MarketeerDataAnnouncement',UIParent,'BackdropTemplate');dialog:SetSize(520,300);dialog:SetPoint('CENTER');dialog:SetFrameStrata('FULLSCREEN_DIALOG');dialog:SetClampedToScreen(true);dialog:EnableMouse(true)
    dialog:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1});dialog:SetBackdropColor(.055,.075,.065,.98);dialog:SetBackdropBorderColor(.25,.58,.37,1)
    local title=dialog:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');title:SetPoint('TOPLEFT',18,-18);title:SetText('IMPORTANT: MARKETEER DATA UPDATE')
    body=dialog:CreateFontString(nil,'OVERLAY','GameFontHighlight');body:SetPoint('TOPLEFT',18,-55);body:SetPoint('TOPRIGHT',-18,-55);body:SetJustifyH('LEFT');body:SetWordWrap(true)
    first='You no longer need the separate Marketeer Data Updater. Market data now comes through the Marketeer data addon.\n\nEnable automatic addon updates in CurseForge, then reload WoW after data updates. We prepare data about every two hours; availability depends on CurseForge and your update settings.\n\nThank you for using Marketeer! Many more amazing updates are coming.'
    nextButton=CreateFrame('Button',nil,dialog,'UIPanelButtonTemplate');nextButton:SetSize(160,26);nextButton:SetPoint('BOTTOMRIGHT',-18,18);nextButton:SetText('Continue')
    back=CreateFrame('Button',nil,dialog,'UIPanelButtonTemplate');back:SetSize(100,26);back:SetPoint('BOTTOMLEFT',18,18);back:SetText('Back')
    confirm=CreateFrame('Button',nil,dialog,'UIPanelButtonTemplate');confirm:SetSize(180,26);confirm:SetPoint('BOTTOMRIGHT',-18,18);confirm:SetText('Yes, I understand')
    nextButton:SetScript('OnClick',function()body:SetText('Are you sure you know you no longer need the separate updater?\n\nIn your AddOns list, you can disable the old Marketeer Data addon. Keep Marketeer Market Data enabled; it replaces the old addon.\n\n|cffffd100HIGHLY RECOMMENDED: Enable automatic updates in CurseForge for Marketeer Market Data.|r\n\nReload WoW after an update to see fresh data. Thank you for being part of Marketeer!');nextButton:Hide();back:Show();confirm:Show()end)
    back:SetScript('OnClick',function()body:SetText(first);back:Hide();confirm:Hide();nextButton:Show()end)
    confirm:SetScript('OnClick',function()MarketeerForeverCoreDB=MarketeerForeverCoreDB or {};MarketeerForeverCoreDB.dataCompanionAcknowledged=true;dialog:Hide()end)
  end
  body:SetText(first);back:Hide();confirm:Hide();nextButton:Show();dialog:Show()
end
-- Report blocked Marketeer actions without showing updater reminders.
local events=CreateFrame('Frame')
for _,event in ipairs({'PLAYER_LOGIN','AUCTION_HOUSE_SHOW','ADDON_ACTION_BLOCKED','ADDON_ACTION_FORBIDDEN'}) do pcall(events.RegisterEvent,events,event) end
local lastBlocked
events:SetScript('OnEvent',function(_,event,addon,action)
  if event=='PLAYER_LOGIN' or event=='AUCTION_HOUSE_SHOW' then if C_Timer and C_Timer.After then C_Timer.After(1,showAnnouncement) else showAnnouncement() end;return end
  if (event=='ADDON_ACTION_BLOCKED' or event=='ADDON_ACTION_FORBIDDEN') and addon=='MarketeerForever' and type(action)=='string' and (not issecretvalue or not issecretvalue(action)) and action~=lastBlocked then
    lastBlocked=action;print('Marketeer: WoW blocked action '..action..'. Please report this message.')
  end
end)
