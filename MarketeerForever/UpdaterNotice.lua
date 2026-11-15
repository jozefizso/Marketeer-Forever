-- Show once per account after this notice is introduced, including new installs.
local dialogKey="MARKETEER_FOREVER_DATA_UPDATER_NOTICE"

StaticPopupDialogs[dialogKey]={
  text="MARKETEER DATA UPDATER\n\nMarket sales per day and price history require the separate Marketeer Forever Data Updater. Without it, much of this market data is unavailable.\n\nFind the updater on the Marketeer Forever CurseForge page. Select your WoW addon folder and your market (region, ruleset and faction), then click Update now. Enable Marketeer Forever Data in the AddOns list and use /reload in game.\n\nRun the updater at least once a day to keep your data current.",
  button1="I understand",
  timeout=0,
  whileDead=true,
  hideOnEscape=false,
  preferredIndex=3,
  OnAccept=function()
    MarketeerForeverCoreDB=MarketeerForeverCoreDB or {}
    MarketeerForeverCoreDB.updaterNoticeAcknowledged=true
  end,
}

local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function()
  if MarketeerForeverCoreDB and MarketeerForeverCoreDB.updaterNoticeAcknowledged then return end
  local function show()
    if not (MarketeerForeverCoreDB and MarketeerForeverCoreDB.updaterNoticeAcknowledged) then
      StaticPopup_Show(dialogKey)
    end
  end
  if C_Timer and C_Timer.After then C_Timer.After(2,show) else show() end
end)
