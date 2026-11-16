-- Remind at the auction house when the updater's current-market data needs attention.
local core=MarketeerForeverCore
local dialogKey='MARKETEER_FOREVER_DATA_UPDATER_REMINDER'
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
StaticPopupDialogs[dialogKey]={
  text='MARKETEER DATA UPDATE NEEDED\n\n%s\n\nMarket demand, price history and other features rely on the Marketeer Data Updater. Visit the Marketeer description on CurseForge and download the updater.\n\nSelect the correct WoW addon folder and your server/market (region, realm type and faction). Run Update now, enable Marketeer Data in your AddOns list, and /reload after the update succeeds.\n\nUpdate daily when you log in for recent 24-hour market data, or leave the updater open and /reload periodically after it updates.',
  button1='Remind me tomorrow',button2='Silence reminders',timeout=0,whileDead=true,hideOnEscape=false,preferredIndex=3,
  OnCancel=function(_,_,reason)
    if reason=='clicked' then
      MarketeerForeverCoreDB=MarketeerForeverCoreDB or {}
      MarketeerForeverCoreDB.silenceUpdaterReminders=true
    end
  end,
}
local events=CreateFrame('Frame')
events:RegisterEvent('AUCTION_HOUSE_SHOW')
events:SetScript('OnEvent',function()
  local function check()
    local db=MarketeerForeverCoreDB
    if not core.active or (db and db.silenceUpdaterReminders) then return end
    local last=db and tonumber(db.updaterReminderAt)
    if last and last<=now() and now()-last<DAY then return end
    local message=status();if not message then return end
    local dialog=StaticPopup_Show(dialogKey,message)
    if dialog then MarketeerForeverCoreDB=MarketeerForeverCoreDB or {};MarketeerForeverCoreDB.updaterReminderAt=now() end
  end
  if C_Timer and C_Timer.After then C_Timer.After(1,check) else check() end
end)
