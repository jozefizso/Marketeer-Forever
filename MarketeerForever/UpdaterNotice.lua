-- Remind at the auction house when the updater's current-market data needs attention.
local core=MarketeerForeverCore
local DAY=24*60*60
local function now() return (GetServerTime and GetServerTime()) or time() end
local function status()
  local market=core.Market and core.Market()
  if not market then return 'Could not verify your current server and faction. Check the updater market selection.' end
  local data=_G.MarketeerForeverMarketData
  local row=type(data)=='table' and data.schemaVersion==1 and data.periodHours==24 and type(data.tables)=='table' and data.tables[market]
  if type(row)~='table' or type(row.text)~='string' or row.text=='' or type(row.updated)~='number' or row.updated<=0 or row.updated>now()+300 then
    return 'Marketeer Data is missing, disabled, invalid, or does not contain this market.'
  end
  local age=now()-row.updated
  if age>=DAY then return 'Your current market data is more than 24 hours old.' end
  local info=MarketeerForeverAPI and MarketeerForeverAPI.GetTableInfo
  local ok,result=pcall(function()return info and info()end)
  if not ok or not result then return 'Marketeer Data for this market could not be read.' end
  return nil
end
-- Keep our reminder out of Blizzard's shared StaticPopupDialogs table.
local dialog,dialogText
local function showReminder(message)
  if not dialog then
    dialog=CreateFrame('Frame','MarketeerUpdaterReminder',UIParent,'BackdropTemplate')
    dialog:SetSize(500,280);dialog:SetPoint('CENTER');dialog:SetFrameStrata('FULLSCREEN_DIALOG');dialog:SetClampedToScreen(true);dialog:EnableMouse(true)
    dialog:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1});dialog:SetBackdropColor(.055,.075,.065,.98);dialog:SetBackdropBorderColor(.25,.48,.34,1)
    local title=dialog:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');title:SetPoint('TOPLEFT',16,-16);title:SetText('MARKETEER DATA UPDATE NEEDED')
    dialogText=dialog:CreateFontString(nil,'OVERLAY','GameFontHighlight');dialogText:SetPoint('TOPLEFT',16,-50);dialogText:SetPoint('TOPRIGHT',-16,-50);dialogText:SetJustifyH('LEFT');dialogText:SetWordWrap(true)
    local later=CreateFrame('Button',nil,dialog,'UIPanelButtonTemplate');later:SetSize(160,25);later:SetPoint('BOTTOMLEFT',16,16);later:SetText('Remind me tomorrow');later:SetScript('OnClick',function()dialog:Hide()end)
    local silence=CreateFrame('Button',nil,dialog,'UIPanelButtonTemplate');silence:SetSize(150,25);silence:SetPoint('BOTTOMRIGHT',-16,16);silence:SetText('Silence reminders');silence:SetScript('OnClick',function()MarketeerForeverCoreDB=MarketeerForeverCoreDB or {};MarketeerForeverCoreDB.silenceUpdaterReminders=true;dialog:Hide()end)
    dialog:Hide()
  end
  dialogText:SetText(message..'\n\nMarket demand, price history and other features rely on the Marketeer Data Updater. Download it from the Marketeer CurseForge page.\n\nSelect the addon folder and your server/market, then choose Update now. Enable Marketeer Data and /reload after updating.\n\nUpdate daily or leave the updater open and /reload periodically.')
  dialog:Show();return dialog
end
local events=CreateFrame('Frame')
events:RegisterEvent('AUCTION_HOUSE_SHOW')
for _,event in ipairs({'ADDON_ACTION_BLOCKED','ADDON_ACTION_FORBIDDEN'}) do pcall(events.RegisterEvent,events,event) end
local lastBlocked
events:SetScript('OnEvent',function(_,event,addon,action)
  if event=='ADDON_ACTION_BLOCKED' or event=='ADDON_ACTION_FORBIDDEN' then
    if addon=='MarketeerForever' and type(action)=='string' and (not issecretvalue or not issecretvalue(action)) and action~=lastBlocked then
      lastBlocked=action;print('Marketeer: WoW blocked action '..action..'. Please report this message.')
    end
    return
  end
  local function check()
    local db=MarketeerForeverCoreDB
    if not core.active or (db and db.silenceUpdaterReminders) then return end
    local last=db and tonumber(db.updaterReminderAt)
    if last and last<=now() and now()-last<DAY then return end
    local message=status();if not message then return end
    local dialog=showReminder(message)
    if dialog then MarketeerForeverCoreDB=MarketeerForeverCoreDB or {};MarketeerForeverCoreDB.updaterReminderAt=now() end
  end
  if C_Timer and C_Timer.After then C_Timer.After(1,check) else check() end
end)
