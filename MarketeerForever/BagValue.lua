-- Estimated value of items carried in bags, using each selling rule's method.
local core=MarketeerForeverCore
local display, valueButton, ellesmereButton, pending
local function money(value)
  value=math.floor(value+0.5)
  local gold=math.floor(value/10000)
  local silver=math.floor(value%10000/100)
  local copper=value%100
  return gold.."|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:0:0|t "..
    silver.."|TInterface\\MoneyFrame\\UI-SilverIcon:14:14:0:0|t "..
    copper.."|TInterface\\MoneyFrame\\UI-CopperIcon:14:14:0:0|t"
end
local function refresh()
  pending=false
  if not valueButton then return end
  local total,missing,priced,excluded,eligible,auctionCount,vendorCount=0,0,0,0,0,0,0
  local container=C_Container
  if not container or not container.GetContainerNumSlots or not container.GetContainerItemInfo then
    valueButton.valueText="--"
    valueButton.detail="Bag contents are unavailable."
    return
  end
  local lastBag=(Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or NUM_BAG_SLOTS or 4
  for bag=0,lastBag do
    for slot=1,(container.GetContainerNumSlots(bag) or 0) do
      local item=container.GetContainerItemInfo(bag,slot)
      if item then
        local id=item.itemID or (item.hyperlink and tonumber(item.hyperlink:match("item:(%d+)")))
        local exclusions=MarketeerForeverCoreDB and MarketeerForeverCoreDB.bagValueExclusions
        if id and exclusions and exclusions[tostring(id)] then
          excluded=excluded+1
        else
        eligible=eligible+1
        local price,method
        if core.BagRuleValue then price,method=core.BagRuleValue(item) end
        if type(price)=="number" and price>0 then
          total=total+price*(item.stackCount or 1);priced=priced+1
          if method=="auction" then auctionCount=auctionCount+1 elseif method=="vendor" then vendorCount=vendorCount+1 end
        else missing=missing+1 end
        end
      end
    end
  end
  valueButton.valueText=(priced>0 or eligible==0) and money(total) or "--"
  valueButton.detail=auctionCount.." AH and "..vendorCount.." vendor stacks; "..missing.." without a price; "..excluded.." excluded."
end
local function schedule()
  if pending then return end
  pending=true
  if C_Timer and C_Timer.After then C_Timer.After(0,refresh) else refresh() end
end
core.RefreshBagValue=schedule
local function restorePosition()
  local bags=_G.ContainerFrameCombinedBags
  local pos=MarketeerForeverCoreDB and MarketeerForeverCoreDB.bagPosition
  if not bags or not pos or type(pos.x)~="number" or type(pos.y)~="number" then return end
  if InCombatLockdown and InCombatLockdown() then return end
  local x,y=pos.x,pos.y
  -- Older releases saved coordinates in UIParent units.
  if pos.version~=2 then local scale=bags:GetEffectiveScale()/UIParent:GetEffectiveScale();x,y=x/scale,y/scale end
  bags:ClearAllPoints()
  bags:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",x,y)
end
local function updateDrag(self)
  if not self.dragging or (InCombatLockdown and InCombatLockdown()) then return end
  local bags=self:GetParent()
  local scale=bags:GetEffectiveScale()
  local x,y=GetCursorPosition()
  x=x/scale-self.dragOffsetX;y=y/scale-self.dragOffsetY
  local uiScale=UIParent:GetEffectiveScale()/scale
  x=math.max(0,math.min(x,math.max(0,UIParent:GetWidth()*uiScale-bags:GetWidth())))
  y=math.max(0,math.min(y,math.max(0,UIParent:GetHeight()*uiScale-bags:GetHeight())))
  bags:ClearAllPoints()
  bags:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",x,y)
  self.dragX,self.dragY=x,y
end
local function finishDrag(self)
  if not self.dragging then return end
  self.dragging=nil;self:SetScript("OnUpdate",nil)
  if self.dragX and self.dragY and MarketeerForeverCoreDB then
    MarketeerForeverCoreDB.bagPosition={x=self.dragX,y=self.dragY,version=2}
  end
end
local function showValueTooltip(self)
  GameTooltip:SetOwner(self,"ANCHOR_TOP")
  GameTooltip:AddLine("Estimated bag value")
  GameTooltip:AddLine((valueButton and valueButton.valueText) or "--",1,1,1)
  GameTooltip:AddLine("Uses each matching bag rule's AH or vendor value. Without a match, uses vendor; if only one price is available, uses that price. Stack quantities are included.",1,1,1,true)
  GameTooltip:AddLine("AH values use the last scan, then the imported reference. Bound items are included; auction fees are not deducted.",1,1,1,true)
  GameTooltip:AddLine((valueButton and valueButton.detail) or "",1,.8,.3,true)
  GameTooltip:AddLine("Click for Marketeer's bag tools.",.7,.8,.75,true)
  GameTooltip:Show()
end
local function setupValueButton()
  if valueButton or not ChatFrame1 then return end
  valueButton=CreateFrame("Button","MarketeerForeverBagValueButton",UIParent,"BackdropTemplate")
  valueButton:SetSize(24,24)
  local pos=MarketeerForeverCoreDB and MarketeerForeverCoreDB.bagValueButtonPosition
  if pos and type(pos.x)=="number" and type(pos.y)=="number" then valueButton:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",pos.x,pos.y)
  else valueButton:SetPoint("BOTTOMLEFT",ChatFrame1,"TOPRIGHT",6,-24) end
  valueButton:SetMovable(true);valueButton:SetClampedToScreen(true);valueButton:RegisterForDrag("LeftButton")
  valueButton:SetScript("OnMouseDown",function(self) self.wasDragged=false end)
  valueButton:SetScript("OnDragStart",function(self) self.wasDragged=true;self:StartMoving() end)
  valueButton:SetScript("OnDragStop",function(self)
    self:StopMovingOrSizing()
    local x,y=self:GetLeft(),self:GetBottom()
    if x and y and MarketeerForeverCoreDB then
      local scale=self:GetEffectiveScale()/UIParent:GetEffectiveScale()
      MarketeerForeverCoreDB.bagValueButtonPosition={x=x*scale,y=y*scale}
    end
  end)
  valueButton:SetScript("OnClick",function(self) if not self.wasDragged and core.OpenTradingMenu then core.OpenTradingMenu("Bag") end end)
  valueButton:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
  valueButton:SetBackdropColor(.07,.08,.07,.9);valueButton:SetBackdropBorderColor(.48,.38,.20,1)
  local icon=valueButton:CreateTexture(nil,"ARTWORK")
  icon:SetPoint("CENTER");icon:SetSize(19,19);icon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
  valueButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
  valueButton:SetScript("OnEnter",showValueTooltip)
  valueButton:SetScript("OnLeave",function() GameTooltip:Hide() end)
  core.UpdateBagCoinVisibility()
end
local function setupEllesmereButton()
  local bags=_G.EUI_Bags or _G.EUI_MainBagFrame
  if ellesmereButton or not bags or (InCombatLockdown and InCombatLockdown()) then return end
  ellesmereButton=CreateFrame("Button",nil,bags,"BackdropTemplate");ellesmereButton:SetSize(20,20)
  local function position()
    ellesmereButton:ClearAllPoints()
    if bags.Footer then ellesmereButton:SetPoint("LEFT",bags.Footer,"LEFT",8,0)
    else ellesmereButton:SetPoint("BOTTOMLEFT",bags,"BOTTOMLEFT",8,4) end
  end
  position();ellesmereButton:SetFrameLevel(bags:GetFrameLevel()+20)
  ellesmereButton:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1});ellesmereButton:SetBackdropColor(.035,.08,.055,.95);ellesmereButton:SetBackdropBorderColor(.25,.65,.40,1)
  local icon=ellesmereButton:CreateTexture(nil,"ARTWORK");icon:SetPoint("CENTER");icon:SetSize(16,16);icon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
  ellesmereButton:SetScript("OnClick",function() if core.OpenTradingMenu then core.OpenTradingMenu("bag") end end)
  ellesmereButton:SetScript("OnEnter",showValueTooltip);ellesmereButton:SetScript("OnLeave",function() GameTooltip:Hide() end)
  bags:HookScript("OnShow",function() schedule();if C_Timer and C_Timer.After then C_Timer.After(0,position) else position() end end)
end
function core.UpdateBagCoinVisibility()
  if valueButton then valueButton:SetShown(MarketeerForeverCoreDB and MarketeerForeverCoreDB.bagCoinEnabled==true) end
end
local function setup()
  local bags=_G.ContainerFrameCombinedBags
  if display or not bags then return end
  display=CreateFrame("Frame",nil,bags)
  display:SetFrameLevel(bags:GetFrameLevel()+20)
  display:SetPoint("CENTER",bags,"BOTTOM",0,0)
  display:SetSize(42,20)
  local grip=display:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
  grip:SetPoint("CENTER");grip:SetText(":::")
  display:EnableMouse(true)
  display:RegisterForDrag("LeftButton")
  display:SetScript("OnDragStart",function(self)
    if InCombatLockdown and InCombatLockdown() then return end
    local left,bottom=bags:GetLeft(),bags:GetBottom()
    if not left or not bottom then return end
    local scale=bags:GetEffectiveScale()
    local x,y=GetCursorPosition()
    self.dragOffsetX=x/scale-left;self.dragOffsetY=y/scale-bottom
    self.dragX,self.dragY=left,bottom
    self.dragging=true
    self:SetScript("OnUpdate",updateDrag)
  end)
  display:SetScript("OnDragStop",finishDrag)
  display:SetScript("OnHide",finishDrag)
  display:SetScript("OnEnter",function(self)
    GameTooltip:SetOwner(self,"ANCHOR_TOP")
    GameTooltip:AddLine("Drag to move bags")
    GameTooltip:AddLine("Available outside combat. Position is saved.",1,1,1,true)
    GameTooltip:Show()
  end)
  display:SetScript("OnLeave",function() GameTooltip:Hide() end)
  bags:HookScript("OnShow",function()
    schedule()
    if C_Timer and C_Timer.After then C_Timer.After(0,restorePosition) else restorePosition() end
  end)
  schedule()
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","ADDON_LOADED","BAG_UPDATE_DELAYED","GET_ITEM_INFO_RECEIVED","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event)
  if event=="PLAYER_LOGIN" or event=="ADDON_LOADED" or event=="PLAYER_REGEN_ENABLED" then setupValueButton();setup();setupEllesmereButton() end
  if event=="PLAYER_REGEN_DISABLED" and display then finishDrag(display) end
  if event=="PLAYER_LOGIN" or event=="PLAYER_REGEN_ENABLED" then restorePosition() end
  schedule()
end)
core.Subscribe(schedule)
