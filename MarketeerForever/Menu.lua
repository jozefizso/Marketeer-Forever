local core=MarketeerForeverCore
local frame,mini,coinCheck,bag,history,bagTab,historyTab
local function text(parent,template,x,y,width)
  local f=parent:CreateFontString(nil,'OVERLAY',template);f:SetPoint('TOPLEFT',x,y);if width then f:SetWidth(width);f:SetJustifyH('LEFT') end;return f
end
local function button(parent,label,x,y,w,action)
  local b=CreateFrame('Button',nil,parent,'BackdropTemplate');b:SetSize(w,26);b:SetPoint('TOPLEFT',x,y);b:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1});b:SetBackdropColor(.07,.09,.08,1);b:SetBackdropBorderColor(.20,.38,.28,1)
  local t=b:CreateFontString(nil,'OVERLAY','GameFontNormal');t:SetPoint('CENTER');t:SetText(label)
  b:SetScript('OnEnter',function(self)self:SetBackdropBorderColor(.30,.78,.48,1)end);b:SetScript('OnLeave',function(self)self:SetBackdropBorderColor(.20,.38,.28,1)end);b:SetScript('OnClick',action);return b
end
local function build()
  if frame then return end
  frame=CreateFrame('Frame','MarketeerForeverMenu',UIParent,'BackdropTemplate');frame:SetSize(790,520);frame:SetPoint('CENTER');frame:SetMovable(true);frame:SetResizable(true);frame:EnableMouse(true);frame:RegisterForDrag('LeftButton');frame:SetClampedToScreen(true)
  core.RegisterEscapeFrame('MarketeerForeverMenu')
  local screenW,screenH=UIParent:GetWidth(),UIParent:GetHeight()
  local maxW,maxH=math.max(790,screenW-20),math.max(520,screenH-20)
  if frame.SetResizeBounds then frame:SetResizeBounds(790,520,maxW,maxH) elseif frame.SetMinResize then frame:SetMinResize(790,520) end
  local db=MarketeerForeverCoreDB or {};frame:SetSize(math.max(790,math.min(maxW,tonumber(db.menuWidth) or 790)),math.max(520,math.min(maxH,tonumber(db.menuHeight) or 520)))
  frame:SetScript('OnDragStart',function(s)s:StartMoving()end);frame:SetScript('OnDragStop',function(s)s:StopMovingOrSizing()end)
  frame:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1});frame:SetBackdropColor(.075,.08,.078,.98);frame:SetBackdropBorderColor(.25,.48,.34,1)
  local sidebar=frame:CreateTexture(nil,'BACKGROUND');sidebar:SetColorTexture(.035,.045,.04,1);sidebar:SetPoint('TOPLEFT');sidebar:SetPoint('BOTTOMLEFT');sidebar:SetWidth(150)
  local accent=frame:CreateTexture(nil,'ARTWORK');accent:SetColorTexture(.22,.65,.40,1);accent:SetPoint('TOPLEFT',frame,'TOPLEFT',150,-58);accent:SetPoint('TOPRIGHT',frame,'TOPRIGHT',-1,-58);accent:SetHeight(1)
  text(frame,'GameFontNormalLarge',18,-22):SetText('|cff62d68eMARKETEER|r')
  local content=CreateFrame('Frame',nil,frame);content:SetPoint('TOPLEFT',frame,'TOPLEFT',150,0);content:SetPoint('BOTTOMRIGHT',frame,'BOTTOMRIGHT',0,0)
  local close=button(frame,'X',585,-14,28,function()frame:Hide()end);close:ClearAllPoints();close:SetPoint('TOPRIGHT',frame,'TOPRIGHT',-15,-14);close:SetFrameLevel(frame:GetFrameLevel()+10)
  local resize=button(frame,'Resize',0,0,62,function()end);resize:ClearAllPoints();resize:SetSize(62,20);resize:SetPoint('BOTTOMRIGHT',frame,'BOTTOMRIGHT',-6,6)
  resize:SetScript('OnMouseDown',function(_,mouseButton)if mouseButton=='LeftButton' then frame:StartSizing('BOTTOMRIGHT') end end)
  local function finishResize() frame:StopMovingOrSizing();if MarketeerForeverCoreDB then MarketeerForeverCoreDB.menuWidth=frame:GetWidth();MarketeerForeverCoreDB.menuHeight=frame:GetHeight() end end
  resize:SetScript('OnMouseUp',finishResize);resize:SetScript('OnHide',finishResize)
  resize:SetScript('OnEnter',function(self)if GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_LEFT');GameTooltip:AddLine('Drag to resize Marketeer');GameTooltip:Show()end end);resize:SetScript('OnLeave',function()if GameTooltip then GameTooltip:Hide() end end)
  bag=CreateFrame('Frame',nil,content);bag:SetAllPoints()
  text(bag,'GameFontNormal',22,-118):SetText('BAG TOOLS')
  text(bag,'GameFontHighlight',24,-151,565):SetText('Keep your bag tools close at hand. Deploy the coin, drag it anywhere, and click it to return here.')
  coinCheck=CreateFrame('CheckButton',nil,bag,'UICheckButtonTemplate');coinCheck:SetPoint('TOPLEFT',22,-205);coinCheck:SetSize(30,30)
  text(bag,'GameFontHighlight',56,-212):SetText('Show movable bag coin')
  coinCheck:SetScript('OnClick',function(s)MarketeerForeverCoreDB.bagCoinEnabled=s:GetChecked() and true or false;if core.UpdateBagCoinVisibility then core.UpdateBagCoinVisibility() end end)
  button(bag,'Bag selling rules',24,-265,160,function()if core.ToggleBagRules then core.ToggleBagRules() end end)
  button(bag,'Excluded items',192,-265,160,function()if core.ShowBagExclusions then core.ShowBagExclusions() end end)
  text(bag,'GameFontHighlightSmall',24,-310,550):SetText('The coin tooltip shows estimated bag value. Selling rules and exclusions use your existing settings.')
  history=core.CreateHistoryPanel(content)
  local function selectTab(which) local h=which=='history';bag:SetShown(not h);history:SetShown(h);bagTab:SetAlpha(h and .65 or 1);historyTab:SetAlpha(h and 1 or .65);if h then history:Refresh() end end
  bagTab=button(frame,'Bag tools',10,-85,130,function()selectTab('bag')end)
  historyTab=button(frame,'Market history',10,-118,130,function()selectTab('history')end)
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
