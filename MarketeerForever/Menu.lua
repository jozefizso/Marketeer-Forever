local core=MarketeerForeverCore
local frame,mini,coinCheck,bag,history,farm,lookup,recipes,auctionChat,hotkeys,toggles,bagTab,historyTab,farmTab,lookupTab,recipesTab,auctionChatTab,hotkeysTab,togglesTab
local lastTab='bag'
local function text(parent,template,x,y,width)
  local f=parent:CreateFontString(nil,'OVERLAY',template);f:SetPoint('TOPLEFT',x,y);if width then f:SetWidth(width);f:SetJustifyH('LEFT') end;return f
end
local function button(parent,label,x,y,w,action)
  local b=CreateFrame('Button',nil,parent,'BackdropTemplate');b:SetSize(w,26);b:SetPoint('TOPLEFT',x,y);b:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1});b:SetBackdropColor(.07,.09,.08,1);b:SetBackdropBorderColor(.20,.38,.28,1)
  local t=b:CreateFontString(nil,'OVERLAY','GameFontNormal');t:SetPoint('CENTER');t:SetText(label)
  b:SetScript('OnEnter',function(self)self:SetBackdropBorderColor(.30,.78,.48,1)end);b:SetScript('OnLeave',function(self)self:SetBackdropBorderColor(.20,.38,.28,1)end);b:SetScript('OnClick',action);return b
end
local discordPopup,discordEdit
local function showDiscord()
  if not discordPopup then
    discordPopup=CreateFrame('Frame','MarketeerForeverDiscordInvite',UIParent,'BackdropTemplate')
    discordPopup:SetSize(460,145);discordPopup:SetPoint('CENTER');discordPopup:SetFrameStrata('FULLSCREEN_DIALOG');discordPopup:SetClampedToScreen(true)
    discordPopup:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1});discordPopup:SetBackdropColor(.055,.075,.065,.98);discordPopup:SetBackdropBorderColor(.25,.48,.34,1)
    text(discordPopup,'GameFontNormal',16,-16,400):SetText('JOIN THE MARKETEER DISCORD')
    text(discordPopup,'GameFontHighlightSmall',16,-42,420):SetText('Join to ask questions, get help, and share feedback.')
    text(discordPopup,'GameFontHighlightSmall',16,-60,420):SetText('Press Ctrl+C to copy the invite, then paste it into your browser.')
    discordEdit=CreateFrame('EditBox',nil,discordPopup,'InputBoxTemplate');discordEdit:SetPoint('TOPLEFT',20,-93);discordEdit:SetSize(415,24);discordEdit:SetAutoFocus(false);discordEdit:SetMaxLetters(200)
    discordEdit:SetScript('OnEscapePressed',function()discordPopup:Hide()end)
    discordPopup:SetScript('OnHide',function()discordEdit:ClearFocus()end)
    local close=CreateFrame('Button',nil,discordPopup,'UIPanelButtonTemplate');close:SetSize(26,22);close:SetPoint('TOPRIGHT',-8,-8);close:SetText('X');close:SetScript('OnClick',function()discordPopup:Hide()end)
    core.RegisterEscapeFrame('MarketeerForeverDiscordInvite')
  end
  discordEdit:SetText('https://discord.gg/RhA3buwnY6');discordPopup:Show();discordEdit:SetFocus();discordEdit:HighlightText()
end
local function build()
  if frame then return end
  frame=CreateFrame('Frame','MarketeerForeverMenu',UIParent,'BackdropTemplate');frame:SetSize(790,520);frame:SetPoint('CENTER');frame:SetMovable(true);frame:SetResizable(true);frame:EnableMouse(true);frame:RegisterForDrag('LeftButton');frame:SetClampedToScreen(true);frame:SetFrameStrata('DIALOG');frame:SetFrameLevel(200)
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
  local discord=button(frame,'Discord',10,-53,130,showDiscord);discord:SetHeight(24)
  local discordIcon=discord:CreateTexture(nil,'ARTWORK');discordIcon:SetSize(20,20);discordIcon:SetPoint('LEFT',discord,'LEFT',12,0);discordIcon:SetTexture('Interface\\AddOns\\MarketeerForever\\Assets\\Discord.tga')
  text(frame,'GameFontHighlightSmall',166,-25,560):SetText('|cff9db9a5Item: Alt+Right = sources / recipe   |   Alt+Left = history   |   Hold Shift = market details|r')
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
  auctionChat=CreateFrame('Frame',nil,content);auctionChat:SetAllPoints()
  text(auctionChat,'GameFontNormalLarge',22,-86,550):SetText('AUCTION CHAT')
  text(auctionChat,'GameFontNormal',24,-129,550):SetText('|cffffd36aCHATTYNATOR IS OPTIONAL|r')
  text(auctionChat,'GameFontHighlight',24,-158,550):SetText('Auction alerts also work with the standard WoW chat window.')
  text(auctionChat,'GameFontHighlight',24,-187,550):SetText('Right-click the chat tab, open Settings, then choose Other and enable Auction House.')
  text(auctionChat,'GameFontNormal',24,-244,550):SetText('CHATTYNATOR')
  text(auctionChat,'GameFontHighlight',24,-273,550):SetText('If you use Chattynator, choose which of its tabs receive auction alerts.')
  button(auctionChat,'Assign Chattynator tabs',24,-312,210,function()if core.ShowAuctionChatSettings then core.ShowAuctionChatSettings() else print('Marketeer: auction chat module did not load. Restart the game or reinstall the addon.') end end)
  text(auctionChat,'GameFontHighlightSmall',24,-354,550):SetText('Allow Marketeer under Addons in each selected Chattynator tab’s filters.')
  hotkeys=CreateFrame('Frame',nil,content);hotkeys:SetAllPoints()
  text(hotkeys,'GameFontNormalLarge',22,-86,550):SetText('HOTKEYS')
  text(hotkeys,'GameFontNormal',24,-132,550):SetText('MONSTER HOVER SNAPSHOT')
  text(hotkeys,'GameFontHighlight',24,-159,550):SetText('Hold the selected key while hovering an enemy to see its loot and market value.')
  local current=text(hotkeys,'GameFontHighlight',24,-194,550)
  local choices={{'Shift','SHIFT'},{'Ctrl','CTRL'},{'Alt','ALT'},{'Off','OFF'}}
  local choicesButtons={}
  local function refreshHotkeys()
    local key=MarketeerForeverCoreDB.farmHoverKey or 'SHIFT'
    local name=key=='CTRL' and 'Ctrl' or key=='ALT' and 'Alt' or key=='OFF' and 'Off' or 'Shift'
    current:SetText('Current: '..name..(key=='OFF' and ' (snapshot disabled)' or '  |  Release the key to close the snapshot.'))
    for _,entry in ipairs(choicesButtons) do entry.button:SetBackdropBorderColor(entry.key==key and .40 or .20,entry.key==key and .85 or .38,entry.key==key and .55 or .28,1) end
  end
  for i,choice in ipairs(choices) do
    local key=choice[2]
    local b=button(hotkeys,choice[1],24+(i-1)*100,-225,90,function()MarketeerForeverCoreDB.farmHoverKey=key;refreshHotkeys()end)
    choicesButtons[#choicesButtons+1]={button=b,key=key}
    b:SetScript('OnLeave',refreshHotkeys)
  end
  hotkeys:SetScript('OnShow',refreshHotkeys)
  toggles=CreateFrame('Frame',nil,content);toggles:SetAllPoints()
  text(toggles,'GameFontNormalLarge',22,-86,550):SetText('TOGGLES')
  local deferCheck=CreateFrame('CheckButton',nil,toggles,'UICheckButtonTemplate');deferCheck:SetPoint('TOPLEFT',20,-128);deferCheck:SetSize(30,30)
  text(toggles,'GameFontHighlight',54,-135,530):SetText('Wait until I visit Your Auctions to check my listings')
  text(toggles,'GameFontHighlightSmall',54,-162,520):SetText('When enabled, undercut and competition checks start after you open Your Auctions each time you visit the auction house. Market auto-scans use their own setting.')
  deferCheck:SetScript('OnClick',function(s)MarketeerForeverCoreDB.deferListingChecks=s:GetChecked() and true or false;if core.OwnedChecksSettingChanged then core.OwnedChecksSettingChanged() end end)
  local combatCheck=CreateFrame('CheckButton',nil,toggles,'UICheckButtonTemplate');combatCheck:SetPoint('TOPLEFT',20,-220);combatCheck:SetSize(30,30)
  text(toggles,'GameFontHighlight',54,-227,500):SetText('Disable monster snapshot tooltip during combat')
  text(toggles,'GameFontHighlightSmall',54,-254,520):SetText('Prevent the monster loot and market snapshot from opening while you are in combat. Change its activation key under Hotkeys.')
  combatCheck:SetScript('OnClick',function(s)MarketeerForeverCoreDB.farmHoverNoCombat=s:GetChecked() and true or false end)
  local silenceCheck=CreateFrame('CheckButton',nil,toggles,'UICheckButtonTemplate');silenceCheck:SetPoint('TOPLEFT',20,-312);silenceCheck:SetSize(30,30)
  text(toggles,'GameFontHighlight',54,-319,500):SetText('Silence Marketeer Data updater reminders')
  text(toggles,'GameFontHighlightSmall',54,-346,520):SetText('Hide reminders about missing or outdated updater data. You can turn reminders back on here.')
  silenceCheck:SetScript('OnClick',function(s)MarketeerForeverCoreDB.silenceUpdaterReminders=s:GetChecked() and true or false end)
  toggles:SetScript('OnShow',function()deferCheck:SetChecked(MarketeerForeverCoreDB.deferListingChecks==true);combatCheck:SetChecked(MarketeerForeverCoreDB.farmHoverNoCombat~=false);silenceCheck:SetChecked(MarketeerForeverCoreDB.silenceUpdaterReminders==true)end)
  history=core.CreateHistoryPanel(content)
  farm=core.CreateFarmPanel(content)
  lookup=core.CreateFarmLookupPanel(content)
  recipes=core.CreateRecipeBrowser(content)
  local function selectTab(which) lastTab=which;local h=which=='history';local f=which=='farm';local l=which=='lookup';local r=which=='recipes';local a=which=='auctionchat';local k=which=='hotkeys';local t=which=='toggles';bag:SetShown(not h and not f and not l and not r and not a and not k and not t);history:SetShown(h);farm:SetShown(f);lookup:SetShown(l);recipes:SetShown(r);auctionChat:SetShown(a);hotkeys:SetShown(k);toggles:SetShown(t);bagTab:SetAlpha(not h and not f and not l and not r and not a and not k and not t and 1 or .65);historyTab:SetAlpha(h and 1 or .65);farmTab:SetAlpha(f and 1 or .65);lookupTab:SetAlpha(l and 1 or .65);recipesTab:SetAlpha(r and 1 or .65);auctionChatTab:SetAlpha(a and 1 or .65);hotkeysTab:SetAlpha(k and 1 or .65);togglesTab:SetAlpha(t and 1 or .65);if h then history:Refresh() end end
  bagTab=button(frame,'Bag tools',10,-85,130,function()selectTab('bag')end)
  historyTab=button(frame,'Market history',10,-118,130,function()selectTab('history')end)
  farmTab=button(frame,'Farm',10,-151,130,function()selectTab('farm')end)
  lookupTab=button(frame,'Find sources',10,-184,130,function()selectTab('lookup')end)
  recipesTab=button(frame,'Recipes',10,-217,130,function()selectTab('recipes')end)
  auctionChatTab=button(frame,'Auction Chat',10,-250,130,function()selectTab('auctionchat')end)
  hotkeysTab=button(frame,'Hotkeys',10,-283,130,function()selectTab('hotkeys')end)
  togglesTab=button(frame,'Toggles',10,-316,130,function()selectTab('toggles')end)
  frame.selectTab=selectTab
  frame:SetScript('OnShow',function()coinCheck:SetChecked(MarketeerForeverCoreDB and MarketeerForeverCoreDB.bagCoinEnabled==true)end)
  frame:Hide()
end
function core.OpenTradingMenu(tab,id,level) build();frame:Show();coinCheck:SetChecked(MarketeerForeverCoreDB and MarketeerForeverCoreDB.bagCoinEnabled==true);frame.selectTab((tab=='bag' or tab=='history' or tab=='farm' or tab=='lookup' or tab=='recipes' or tab=='auctionchat' or tab=='hotkeys' or tab=='toggles') and tab or lastTab);if tab=='history' and id then history:SetItem(id) elseif tab=='lookup' and id then lookup:SetItem(id) elseif tab=='farm' and id then core.SelectFarmMonster(id,level) elseif tab=='recipes' and id then recipes:SetItem(id) end end
function core.ShowMarketHistory(id) core.OpenTradingMenu('history',id) end
function core.ShowItemDrops(id) core.OpenTradingMenu('lookup',tonumber(id)) end
function core.ShowFarmMonster(id,level) core.OpenTradingMenu('farm',tonumber(id),level) end
function core.ShowItemRecipes(id) core.OpenTradingMenu('recipes',tonumber(id)) end
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
SLASH_MARKETEERFOREVERMENU1='/marketeer';SLASH_MARKETEERFOREVERMENU2='/ntrading';SlashCmdList.MARKETEERFOREVERMENU=function(msg)
  local drops=type(msg)=='string' and msg:match('^%s*drops%s+(.+)%s*$')
  if drops then local id=tonumber(drops:match('item:(%d+)') or drops);if id then core.ShowItemDrops(id) else print('Marketeer: use /marketeer drops followed by an item ID or link.') end;return end
  local id=type(msg)=='string' and tonumber(msg:match('item:(%d+)') or msg:match('^%s*(%d+)%s*$'));if id then core.ShowMarketHistory(id) else core.OpenTradingMenu() end
end
local events=CreateFrame('Frame');events:RegisterEvent('PLAYER_LOGIN');events:SetScript('OnEvent',function()setupMini()end)
-- Additive hooks preserve the game's existing modified-click behavior.
local function altOnly() return IsAltKeyDown and IsAltKeyDown() and not (IsShiftKeyDown and IsShiftKeyDown()) and not (IsControlKeyDown and IsControlKeyDown()) end
local function openItemSources(id)
  if not id or (issecretvalue and issecretvalue(id)) or type(id)~='number' or not altOnly() or (InCombatLockdown and InCombatLockdown()) then return end
  local entry=MarketeerForeverFarmLookup and MarketeerForeverFarmLookup.items[id]
  if core.HasItemRecipe and core.HasItemRecipe(id) and (not entry or #entry.drops==0) then core.ShowItemRecipes(id) else core.ShowItemDrops(id) end
end
local function openFromLink(link)
  local id=type(link)=='string' and tonumber(link:match('item:(%d+)'))
  if id and altOnly() and not (InCombatLockdown and InCombatLockdown()) then core.ShowMarketHistory(id) end
end
if hooksecurefunc and type(SetItemRef)=='function' then hooksecurefunc('SetItemRef',function(link,_,mouseButton)if mouseButton=='LeftButton' then openFromLink(link) elseif mouseButton=='RightButton' and type(link)=='string' then openItemSources(tonumber(link:match('item:(%d+)'))) end end) end
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
-- Observe the native bag click without replacing its protected handler.
if hooksecurefunc and type(ContainerFrameItemButtonMixin)=='table' then
  local method=type(ContainerFrameItemButtonMixin.OnClick)=='function' and 'OnClick' or (type(ContainerFrameItemButtonMixin.OnModifiedClick)=='function' and 'OnModifiedClick')
  if method then hooksecurefunc(ContainerFrameItemButtonMixin,method,function(self,mouseButton)
    if mouseButton~='RightButton' or not altOnly() or (InCombatLockdown and InCombatLockdown()) then return end
    local okBag,bag=pcall(function() return self.GetBagID and self:GetBagID() end)
    local okSlot,slot=pcall(function() return self.GetID and self:GetID() end)
    if not okBag or not okSlot or (issecretvalue and (issecretvalue(bag) or issecretvalue(slot))) or type(bag)~='number' or type(slot)~='number' or not C_Container or not C_Container.GetContainerItemInfo then return end
    local ok,info=pcall(C_Container.GetContainerItemInfo,bag,slot)
    local id=ok and type(info)=='table' and info.itemID
    if issecretvalue and issecretvalue(id) then return end
    if type(id)=='number' then
      openItemSources(id)
    end
  end) end
end
-- Auction UI loads on demand, so install its additive hook when it becomes available.
local auctionHooked=false
local function installAuctionHook()
  if auctionHooked or not hooksecurefunc or type(AuctionHouseItemDisplayMixin)~='table' or type(AuctionHouseItemDisplayMixin.OnClick)~='function' then return end
  hooksecurefunc(AuctionHouseItemDisplayMixin,'OnClick',function(self,button)
    if button~='RightButton' or not altOnly() then return end
    local ok,id=pcall(function() local key=self.GetItemKey and self:GetItemKey();return (key and key.itemID) or (self.GetItemID and self:GetItemID()) end)
    if ok then openItemSources(id) end
  end)
  auctionHooked=true
end
local shortcutEvents=CreateFrame('Frame');shortcutEvents:RegisterEvent('ADDON_LOADED');shortcutEvents:SetScript('OnEvent',installAuctionHook);installAuctionHook()
