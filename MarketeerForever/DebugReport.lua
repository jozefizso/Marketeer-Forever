-- Independent of Blizzard's protected blocked-action dialog.
local core=MarketeerForeverCore
local events=CreateFrame('Frame')
local recent={};local prompt,window,edit,lastReport
local function safe(value)
  if issecretvalue and issecretvalue(value) then return nil end
  local t=type(value);if t=='string' or t=='number' or t=='boolean' then return value end
end
local function call(fn,...)
  if type(fn)~='function' then return nil end
  local result={pcall(fn,...)};if not result[1] then return nil end
  return safe(result[2]),safe(result[3]),safe(result[4]),safe(result[5])
end
local function addonVersion(name)
  local api=C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
  return call(api,name,'Version') or 'unknown'
end
local function loaded(name)
  local api=C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
  local value=call(api,name);return value==true or value==1
end
local function shown(frame)
  return frame and call(frame.IsShown,frame)==true or false
end
local function report(event,action)
  local version,build,buildDate,interface=call(GetBuildInfo)
  local bagAddons={}
  for _,name in ipairs({'Baganator','ArkInventory','EUIStandaloneBags','NokiForever'}) do if loaded(name) then bagAddons[#bagAddons+1]=name end end
  local ageNow=call(GetTime) or 0;local history={}
  for _,entry in ipairs(recent) do local age=math.max(0,math.floor(ageNow-entry.time));if age<=300 then history[#history+1]=entry.event..' ('..age..'s ago)' end end
  return table.concat({
    'Marketeer blocked-action report',
    'Marketeer version: '..tostring(addonVersion('MarketeerForever')),
    'WoW client: '..tostring(version or '?')..' / build '..tostring(build or '?')..' / interface '..tostring(interface or '?'),
    'Event: '..tostring(event or '?'),
    'Blocked action: '..tostring(action or 'unavailable'),
    'In combat: '..tostring(call(InCombatLockdown)==true),
    'Merchant open: '..tostring(shown(MerchantFrame)),
    'Auction house open: '..tostring(shown(AuctionHouseFrame)),
    'Loaded bag addons: '..(#bagAddons>0 and table.concat(bagAddons,', ') or 'none detected'),
    'Recent events: '..(#history>0 and table.concat(history,', ') or 'none recorded'),
    'Taint logging: '..tostring(call(GetCVar,'taintLog') or 'unknown'),
    'This report does not include a taint log or identify the root cause.',
  },'\n')
end
local function createWindow()
  if window then return end
  window=CreateFrame('Frame','MarketeerDebugCopyWindow',UIParent,'BackdropTemplate');window:SetSize(590,330);window:SetPoint('CENTER');window:SetFrameStrata('FULLSCREEN_DIALOG');window:SetClampedToScreen(true);window:EnableMouse(true)
  window:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1});window:SetBackdropColor(.04,.07,.055,.98);window:SetBackdropBorderColor(.3,.65,.4,1)
  local title=window:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');title:SetPoint('TOPLEFT',16,-14);title:SetText('COPY DEBUG DATA')
  local instructions=window:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');instructions:SetPoint('TOPLEFT',16,-38);instructions:SetText('Press Ctrl+C, then paste the report to the Marketeer team.')
  edit=CreateFrame('EditBox',nil,window,'InputBoxTemplate');edit:SetPoint('TOPLEFT',16,-62);edit:SetSize(555,220);edit:SetMultiLine(true);edit:SetAutoFocus(false);edit:SetFontObject('ChatFontNormal');edit:SetMaxLetters(6000)
  edit:SetScript('OnEscapePressed',function(self)self:ClearFocus()end)
  local close=CreateFrame('Button',nil,window,'UIPanelButtonTemplate');close:SetSize(95,24);close:SetPoint('BOTTOMRIGHT',-16,12);close:SetText('Close');close:SetScript('OnClick',function()edit:ClearFocus();window:Hide()end)
  window:Hide()
end
function core.ShowBlockedActionReport()
  if not lastReport then print('Marketeer: no blocked-action report is available yet.');return end
  createWindow();edit:SetText(lastReport);window:Show();edit:SetFocus();edit:HighlightText()
end
local function createPrompt()
  if prompt then return end
  prompt=CreateFrame('Frame','MarketeerBlockedActionPrompt',UIParent,'BackdropTemplate');prompt:SetSize(190,34);prompt:SetFrameStrata('FULLSCREEN_DIALOG');prompt:SetClampedToScreen(true)
  prompt:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1});prompt:SetBackdropColor(.04,.07,.055,.98);prompt:SetBackdropBorderColor(.3,.65,.4,1)
  local copy=CreateFrame('Button',nil,prompt,'UIPanelButtonTemplate');copy:SetSize(150,24);copy:SetPoint('LEFT',5,0);copy:SetText('Copy debug data');copy:SetScript('OnClick',function()core.ShowBlockedActionReport();prompt:Hide()end)
  local close=CreateFrame('Button',nil,prompt,'UIPanelButtonTemplate');close:SetSize(26,24);close:SetPoint('RIGHT',-4,0);close:SetText('X');close:SetScript('OnClick',function()prompt:Hide()end)
  prompt:Hide()
end
local function showPrompt()
  createPrompt();prompt:ClearAllPoints()
  local popup=call(StaticPopup_Visible,'ADDON_ACTION_FORBIDDEN')
  -- Some clients return a frame, which call() intentionally rejects. Read its
  -- coordinates directly without parenting to or changing Blizzard's dialog.
  if type(StaticPopup_Visible)=='function' then local ok,value=pcall(StaticPopup_Visible,'ADDON_ACTION_FORBIDDEN');if ok and type(value)=='table' then popup=value end end
  local left=popup and call(popup.GetLeft,popup);local bottom=popup and call(popup.GetBottom,popup)
  local ps=popup and call(popup.GetEffectiveScale,popup);local us=UIParent and call(UIParent.GetEffectiveScale,UIParent)
  if type(left)=='number' and type(bottom)=='number' and type(ps)=='number' and type(us)=='number' and us>0 then
    prompt:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',left*ps/us,bottom*ps/us-4)
  else prompt:SetPoint('CENTER',UIParent,'CENTER',0,120) end
  prompt:Show()
end
function core.PreviewBlockedActionReport()
  lastReport=report('TEST', 'ExampleAction (test)')
  showPrompt()
end
for _,event in ipairs({'ADDON_ACTION_BLOCKED','ADDON_ACTION_FORBIDDEN','MAIL_SHOW','MAIL_CLOSED','MERCHANT_SHOW','MERCHANT_CLOSED','AUCTION_HOUSE_SHOW','AUCTION_HOUSE_CLOSED','PLAYER_ENTERING_WORLD'}) do pcall(events.RegisterEvent,events,event) end
events:SetScript('OnEvent',function(_,event,a,b)
  if event=='ADDON_ACTION_BLOCKED' or event=='ADDON_ACTION_FORBIDDEN' then
    if safe(a)~='MarketeerForever' then return end
    lastReport=report(event,safe(b))
    if C_Timer and C_Timer.After then C_Timer.After(.1,showPrompt) else showPrompt() end
  else recent[#recent+1]={event=event,time=call(GetTime) or 0};if #recent>8 then table.remove(recent,1) end end
end)
