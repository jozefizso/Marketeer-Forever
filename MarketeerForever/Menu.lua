local core=MarketeerForeverCore
local frame,mini,coinCheck,bag,history,bagTab,historyTab
local function text(parent,template,x,y,width)
  local f=parent:CreateFontString(nil,'OVERLAY',template);f:SetPoint('TOPLEFT',x,y);if width then f:SetWidth(width);f:SetJustifyH('LEFT') end;return f
end
local function button(parent,label,x,y,w,action)
  local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetSize(w,26);b:SetPoint('TOPLEFT',x,y);b:SetText(label);b:SetScript('OnClick',action);return b
end
local function build()
  if frame then return end
  frame=CreateFrame('Frame','MarketeerForeverMenu',UIParent,'BackdropTemplate');frame:SetSize(630,520);frame:SetPoint('CENTER');frame:SetMovable(true);frame:EnableMouse(true);frame:RegisterForDrag('LeftButton');frame:SetClampedToScreen(true)
  frame:SetScript('OnDragStart',function(s)s:StartMoving()end);frame:SetScript('OnDragStop',function(s)s:StopMovingOrSizing()end)
  frame:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1});frame:SetBackdropColor(.025,.045,.038,.98);frame:SetBackdropBorderColor(.20,.43,.29,1)
  text(frame,'GameFontNormalLarge',22,-20):SetText('MARKETEER')
  text(frame,'GameFontHighlightSmall',23,-44):SetText('Your market companion')
  local close=button(frame,'X',585,-14,28,function()frame:Hide()end);close:ClearAllPoints();close:SetPoint('TOPRIGHT',frame,'TOPRIGHT',-15,-14);close:SetFrameLevel(frame:GetFrameLevel()+10)
  bag=CreateFrame('Frame',nil,frame);bag:SetAllPoints()
  text(bag,'GameFontNormal',22,-118):SetText('BAG TOOLS')
  text(bag,'GameFontHighlight',24,-151,565):SetText('Keep your bag tools close at hand. Deploy the coin, drag it anywhere, and click it to return here.')
  coinCheck=CreateFrame('CheckButton',nil,bag,'UICheckButtonTemplate');coinCheck:SetPoint('TOPLEFT',22,-205);coinCheck:SetSize(30,30)
  text(bag,'GameFontHighlight',56,-212):SetText('Show movable bag coin')
  coinCheck:SetScript('OnClick',function(s)MarketeerForeverCoreDB.bagCoinEnabled=s:GetChecked() and true or false;if core.UpdateBagCoinVisibility then core.UpdateBagCoinVisibility() end end)
  button(bag,'Bag selling rules',24,-265,160,function()if core.ToggleBagRules then core.ToggleBagRules() end end)
  button(bag,'Excluded items',192,-265,160,function()if core.ShowBagExclusions then core.ShowBagExclusions() end end)
  text(bag,'GameFontHighlightSmall',24,-310,550):SetText('The coin tooltip shows estimated bag value. Selling rules and exclusions use your existing settings.')
  history=core.CreateHistoryPanel(frame)
  local function selectTab(which) local h=which=='history';bag:SetShown(not h);history:SetShown(h);bagTab:SetAlpha(h and .65 or 1);historyTab:SetAlpha(h and 1 or .65);if h then history:Refresh() end end
  bagTab=button(frame,'Bag',22,-75,100,function()selectTab('bag')end)
  historyTab=button(frame,'Market history',130,-75,130,function()selectTab('history')end)
  frame.selectTab=selectTab
  frame:SetScript('OnShow',function()coinCheck:SetChecked(MarketeerForeverCoreDB and MarketeerForeverCoreDB.bagCoinEnabled==true)end)
  frame:Hide()
end
function core.OpenTradingMenu(tab,id) build();frame:Show();coinCheck:SetChecked(MarketeerForeverCoreDB and MarketeerForeverCoreDB.bagCoinEnabled==true);frame.selectTab(tab=='history' and 'history' or 'bag');if tab=='history' and id then history:SetItem(id) end end
function core.ShowMarketHistory(id) core.OpenTradingMenu('history',id) end
local function setupMini()
  if mini then return end
  mini=CreateFrame('Button','MarketeerForeverMinimapButton',Minimap);mini:SetSize(32,32);mini:SetFrameStrata('MEDIUM');mini:RegisterForDrag('LeftButton');mini:RegisterForClicks('LeftButtonUp')
  local bg=mini:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints();bg:SetTexture('Interface\\MoneyFrame\\UI-GoldIcon')
  local border=mini:CreateTexture(nil,'OVERLAY');border:SetSize(54,54);border:SetPoint('TOPLEFT',-1,1);border:SetTexture('Interface\\Minimap\\MiniMap-TrackingBorder')
  local function position(a)local rad=math.rad(a or 135);local radius=(Minimap:GetWidth() or 140)/2+5;mini:ClearAllPoints();mini:SetPoint('CENTER',Minimap,'CENTER',math.cos(rad)*radius,math.sin(rad)*radius)end
  position(MarketeerForeverCoreDB.tradingMinimapAngle)
  mini:SetScript('OnDragStart',function(s)s.dragged=true;s:SetScript('OnUpdate',function()local x,y=GetCursorPosition();local scale=Minimap:GetEffectiveScale();local cx,cy=Minimap:GetCenter();if cx and cy then local a=math.deg(math.atan2(y/scale-cy,x/scale-cx));MarketeerForeverCoreDB.tradingMinimapAngle=a;position(a)end end)end)
  mini:SetScript('OnDragStop',function(s)s:SetScript('OnUpdate',nil)end)
  mini:SetScript('OnMouseDown',function(s)s.dragged=false end);mini:SetScript('OnClick',function(s)if not s.dragged then core.OpenTradingMenu()end end)
  mini:SetScript('OnEnter',function(s)GameTooltip:SetOwner(s,'ANCHOR_LEFT');GameTooltip:AddLine('Marketeer');GameTooltip:AddLine('Click: open menu | Drag: move',1,1,1);GameTooltip:Show()end);mini:SetScript('OnLeave',function()GameTooltip:Hide()end)
end
SLASH_MARKETEERFOREVERMENU1='/marketeer';SLASH_MARKETEERFOREVERMENU2='/ntrading';SlashCmdList.MARKETEERFOREVERMENU=function(msg)local id=type(msg)=='string' and tonumber(msg:match('item:(%d+)') or msg:match('^%s*(%d+)%s*$'));if id then core.ShowMarketHistory(id) else core.OpenTradingMenu() end end
local events=CreateFrame('Frame');events:RegisterEvent('PLAYER_LOGIN');events:SetScript('OnEvent',function()setupMini()end)
-- Additive hooks preserve the game's existing modified-click behavior.
local function altOnly() return IsAltKeyDown and IsAltKeyDown() and not (IsShiftKeyDown and IsShiftKeyDown()) and not (IsControlKeyDown and IsControlKeyDown()) end
local function openFromLink(link)
  local id=type(link)=='string' and tonumber(link:match('item:(%d+)'))
  if id and altOnly() and not (InCombatLockdown and InCombatLockdown()) then core.ShowMarketHistory(id) end
end
if hooksecurefunc and type(SetItemRef)=='function' then hooksecurefunc('SetItemRef',function(link,_,mouseButton)if mouseButton=='LeftButton' then openFromLink(link) end end) end
if hooksecurefunc and type(HandleModifiedItemClick)=='function' then hooksecurefunc('HandleModifiedItemClick',function(link)if IsMouseButtonDown and IsMouseButtonDown('LeftButton') then openFromLink(link) end end) end
if hooksecurefunc and type(ContainerFrameItemButtonMixin)=='table' and type(ContainerFrameItemButtonMixin.OnModifiedClick)=='function' then
  hooksecurefunc(ContainerFrameItemButtonMixin,'OnModifiedClick',function(self,mouseButton)
    if mouseButton~='LeftButton' or not altOnly() or (InCombatLockdown and InCombatLockdown()) then return end
    local bag=self.GetBagID and self:GetBagID();local slot=self.GetID and self:GetID()
    if type(bag)=='number' and type(slot)=='number' and C_Container and C_Container.GetContainerItemInfo then
      local info=C_Container.GetContainerItemInfo(bag,slot);local id=type(info)=='table' and info.itemID
      if type(id)=='number' then core.ShowMarketHistory(id) end
    end
  end)
end
