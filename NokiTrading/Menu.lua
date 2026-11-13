local core=NokiUnifiedCore
local frame,mini,coinCheck
local function text(parent,template,x,y,width)
  local f=parent:CreateFontString(nil,'OVERLAY',template);f:SetPoint('TOPLEFT',x,y);if width then f:SetWidth(width);f:SetJustifyH('LEFT') end;return f
end
local function button(parent,label,x,y,w,action)
  local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetSize(w,26);b:SetPoint('TOPLEFT',x,y);b:SetText(label);b:SetScript('OnClick',action);return b
end
local function build()
  if frame then return end
  frame=CreateFrame('Frame','NokiTradingMenu',UIParent,'BackdropTemplate');frame:SetSize(630,420);frame:SetPoint('CENTER');frame:SetMovable(true);frame:EnableMouse(true);frame:RegisterForDrag('LeftButton');frame:SetClampedToScreen(true)
  frame:SetScript('OnDragStart',function(s)s:StartMoving()end);frame:SetScript('OnDragStop',function(s)s:StopMovingOrSizing()end)
  frame:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1});frame:SetBackdropColor(.025,.045,.038,.98);frame:SetBackdropBorderColor(.20,.43,.29,1)
  text(frame,'GameFontNormalLarge',22,-20):SetText('MARKETEER')
  text(frame,'GameFontHighlightSmall',23,-44):SetText('Your market companion')
  local close=button(frame,'X',585,-14,28,function()frame:Hide()end);close:ClearAllPoints();close:SetPoint('TOPRIGHT',frame,'TOPRIGHT',-15,-14);close:SetFrameLevel(frame:GetFrameLevel()+10)
  text(frame,'GameFontNormal',22,-92):SetText('BAG TOOLS')
  text(frame,'GameFontHighlight',24,-125,565):SetText('Keep your bag tools close at hand. Deploy the coin, drag it anywhere, and click it to return here.')
  coinCheck=CreateFrame('CheckButton',nil,frame,'UICheckButtonTemplate');coinCheck:SetPoint('TOPLEFT',22,-175);coinCheck:SetSize(30,30)
  text(frame,'GameFontHighlight',56,-182):SetText('Show movable bag coin')
  coinCheck:SetScript('OnClick',function(s)NokiUnifiedCoreDB.bagCoinEnabled=s:GetChecked() and true or false;if core.UpdateBagCoinVisibility then core.UpdateBagCoinVisibility() end end)
  button(frame,'Bag selling rules',24,-235,160,function()if core.ToggleBagRules then core.ToggleBagRules() end end)
  button(frame,'Excluded items',192,-235,160,function()if core.ShowBagExclusions then core.ShowBagExclusions() end end)
  text(frame,'GameFontHighlightSmall',24,-280,550):SetText('The coin tooltip shows estimated bag value. Selling rules and exclusions use your existing settings.')
  frame:SetScript('OnShow',function()coinCheck:SetChecked(NokiUnifiedCoreDB and NokiUnifiedCoreDB.bagCoinEnabled==true)end)
  frame:Hide()
end
function core.OpenTradingMenu() build();frame:Show();coinCheck:SetChecked(NokiUnifiedCoreDB and NokiUnifiedCoreDB.bagCoinEnabled==true) end
local function setupMini()
  if mini then return end
  mini=CreateFrame('Button','NokiTradingMinimapButton',Minimap);mini:SetSize(32,32);mini:SetFrameStrata('MEDIUM');mini:RegisterForDrag('LeftButton');mini:RegisterForClicks('LeftButtonUp')
  local bg=mini:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints();bg:SetTexture('Interface\\MoneyFrame\\UI-GoldIcon')
  local border=mini:CreateTexture(nil,'OVERLAY');border:SetSize(54,54);border:SetPoint('TOPLEFT',-1,1);border:SetTexture('Interface\\Minimap\\MiniMap-TrackingBorder')
  local function position(a)local rad=math.rad(a or 135);local radius=(Minimap:GetWidth() or 140)/2+5;mini:ClearAllPoints();mini:SetPoint('CENTER',Minimap,'CENTER',math.cos(rad)*radius,math.sin(rad)*radius)end
  position(NokiUnifiedCoreDB.tradingMinimapAngle)
  mini:SetScript('OnDragStart',function(s)s.dragged=true;s:SetScript('OnUpdate',function()local x,y=GetCursorPosition();local scale=Minimap:GetEffectiveScale();local cx,cy=Minimap:GetCenter();if cx and cy then local a=math.deg(math.atan2(y/scale-cy,x/scale-cx));NokiUnifiedCoreDB.tradingMinimapAngle=a;position(a)end end)end)
  mini:SetScript('OnDragStop',function(s)s:SetScript('OnUpdate',nil)end)
  mini:SetScript('OnMouseDown',function(s)s.dragged=false end);mini:SetScript('OnClick',function(s)if not s.dragged then core.OpenTradingMenu()end end)
  mini:SetScript('OnEnter',function(s)GameTooltip:SetOwner(s,'ANCHOR_LEFT');GameTooltip:AddLine('Marketeer');GameTooltip:AddLine('Click: open menu | Drag: move',1,1,1);GameTooltip:Show()end);mini:SetScript('OnLeave',function()GameTooltip:Hide()end)
end
SLASH_NOKITRADINGMENU1='/ntrading';SlashCmdList.NOKITRADINGMENU=function()core.OpenTradingMenu()end
local events=CreateFrame('Frame');events:RegisterEvent('PLAYER_LOGIN');events:SetScript('OnEvent',function()setupMini()end)
