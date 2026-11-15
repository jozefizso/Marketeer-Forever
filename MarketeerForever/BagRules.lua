-- Configurable vendor-versus-auction indicators for bag slots.
local core=MarketeerForeverCore
local dots=setmetatable({},{__mode="k"})
local pending,window,rows,status=false,nil,{},nil
local auctionOpen,merchantOpen=false,false
local function markersVisible()
  return not (MarketeerForeverCoreDB and MarketeerForeverCoreDB.bagMarkersTradingOnly) or auctionOpen or merchantOpen or (IsShiftKeyDown and IsShiftKeyDown())
end
local defaults={{threshold=15,r=1,g=0,b=0},{threshold=10,r=1,g=1,b=0},{threshold=-1,r=0,g=1,b=0}}
local function ruleMethod(rule)
  if rule.method=="auction" or rule.method=="vendor" then return rule.method end
  -- Existing color-only rules have no sale method. Seed a sensible starting
  -- choice without changing their colors or percentage thresholds.
  return type(rule.threshold)=="number" and rule.threshold>=10 and "auction" or "vendor"
end
local function rules()
  if not MarketeerForeverCoreDB then return {} end
  local db=MarketeerForeverCoreDB
  if type(db.bagRules)~="table" then
    db.bagRules={}
    for i,v in ipairs(defaults) do db.bagRules[i]={threshold=v.threshold,r=v.r,g=v.g,b=v.b} end
    db.bagRulesVersion=3
  elseif db.bagRulesVersion~=3 then
    local converted={}
    for _,v in ipairs(db.bagRules) do
      local threshold
      if db.bagRulesVersion==2 and type(v.threshold)=="number" then threshold=100-v.threshold
      elseif type(v.min)=="number" and type(v.max)=="number" then threshold=v.min end
      if threshold and threshold>=-9900 and threshold<=100 then converted[#converted+1]={threshold=threshold,r=v.r,g=v.g,b=v.b} end
    end
    table.sort(converted,function(a,b) return a.threshold>b.threshold end)
    db.bagRules=converted;db.bagRulesVersion=3
  end
  return db.bagRules
end
local function priceFor(id)
  local market=core.Market()
  local book=market and MarketeerForeverCoreDB and MarketeerForeverCoreDB.prices and MarketeerForeverCoreDB.prices[market]
  local row=book and book.items and book.items[id]
  if row and type(row.price)=="number" and row.price>0 then return row.price end
  local reference=MarketeerForeverAPI and MarketeerForeverAPI.GetPrice(id)
  return reference and reference.minBuyout
end
local function vendorFor(id,link)
  local getInfo=(C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not getInfo then return nil end
  local values={pcall(getInfo,link or id)}
  if values[1] and type(values[12])=="number" then return values[12] end
  if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID,id) end
end
-- Only apply the vendor-only fallback when the actual bag stack can be
-- verified as neither quest-related nor bound. Item IDs alone are not enough.
local function vendorFallbackEligible(bag,slot)
  local c=C_Container
  if type(bag)~="number" or type(slot)~="number" or not c or not c.GetContainerItemInfo or not c.GetContainerItemQuestInfo then return false end
  local info=c.GetContainerItemInfo(bag,slot)
  if not info then return false end
  local ok,quest=pcall(c.GetContainerItemQuestInfo,bag,slot)
  if not ok or (quest and (quest.isQuestItem or quest.questID)) then return false end
  if type(info.isBound)=="boolean" then return not info.isBound end
  if not C_Item or not C_Item.IsBound or not ItemLocation or not ItemLocation.CreateFromBagAndSlot then return false end
  local made,location=pcall(ItemLocation.CreateFromBagAndSlot,ItemLocation,bag,slot)
  if not made or not location then return false end
  local checked,bound=pcall(C_Item.IsBound,location)
  return checked and bound==false
end
local function lowestVendorRule()
  local lowest
  for _,rule in ipairs(rules()) do
    if type(rule.threshold)=="number" and ruleMethod(rule)=="vendor" and (not lowest or rule.threshold<lowest.threshold) then lowest=rule end
  end
  return lowest
end
local function matchingRule(id,link,bag,slot)
  local excluded=MarketeerForeverCoreDB and MarketeerForeverCoreDB.bagValueExclusions
  if excluded and excluded[tostring(id)] then return nil end
  local ah,vendor=priceFor(id),vendorFor(id,link)
  if type(vendor)~="number" or vendor<=0 then return nil end
  if type(ah)~="number" or ah<=0 then
    if not vendorFallbackEligible(bag,slot) then return nil end
    return lowestVendorRule()
  end
  if vendor>ah then return lowestVendorRule() end
  local percent=(ah-vendor)*100/ah
  for _,rule in ipairs(rules()) do
    if type(rule.threshold)=="number" and percent>rule.threshold then return rule end
  end
end
function core.BagRuleValue(item)
  if type(item)~="table" then return nil end
  local id=item.itemID or (item.hyperlink and tonumber(item.hyperlink:match("item:(%d+)")))
  if not id then return nil end
  local ah,vendor=priceFor(id),vendorFor(id,item.hyperlink)
  ah=type(ah)=="number" and ah>0 and ah or nil
  vendor=type(vendor)=="number" and vendor>0 and vendor or nil
  if ah and vendor then
    if vendor>ah then return vendor,"vendor" end
    local percent=(ah-vendor)*100/ah
    for _,rule in ipairs(rules()) do
      if type(rule.threshold)=="number" and percent>rule.threshold then
        if ruleMethod(rule)=="auction" then return ah,"auction" else return vendor,"vendor" end
      end
    end
    return vendor,"vendor"
  end
  if vendor then return vendor,"vendor" end
  if ah then return ah,"auction" end
end
local function paint(button,bag,slot)
  local dot=dots[button]
  if not markersVisible() then if dot then dot:Hide() end;return end
  -- A texture is cosmetic: creating it does not create a protected item
  -- button or change its actions. Bag slots may first appear during combat.
  if not dot then
    local layer=button._textOverlay or button
    dot=layer:CreateTexture(nil,"OVERLAY",nil,7);dot:SetSize(9,9);dot:SetPoint("BOTTOMLEFT",button,"BOTTOMLEFT",3,3);dot:Hide();dots[button]=dot
  end
  local info=C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag,slot)
  local id=info and (info.itemID or (info.hyperlink and tonumber(info.hyperlink:match("item:(%d+)"))))
  local selected=id and matchingRule(id,info.hyperlink,bag,slot)
  if not selected then if dot then dot:Hide() end;return end
  dot:SetColorTexture(selected.r or 1,selected.g or 1,selected.b or 1,1);dot:Show()
end
-- Recheck the exact bag slot when its item tooltip becomes available. Item
-- details can arrive after the initial bag repaint, particularly after login.
function core.RefreshBagRuleForTooltip(tooltip,id)
  local button=tooltip and tooltip.GetOwner and tooltip:GetOwner()
  if not button or not button.GetID then return end
  local slot=button:GetID();local bag=button.GetBagID and button:GetBagID()
  local parent=button.GetParent and button:GetParent()
  if type(bag)~="number" and button._textOverlay and parent and parent.GetID then bag=parent:GetID() end
  local last=(Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or NUM_BAG_SLOTS or 4
  if type(bag)~="number" or bag<0 or bag>last or type(slot)~="number" or slot<1 then return end
  local info=C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag,slot)
  local itemID=info and (info.itemID or (info.hyperlink and tonumber(info.hyperlink:match("item:(%d+)"))))
  if itemID==id then pcall(paint,button,bag,slot) end
end
-- Ellesmere's inventory owns a pooled set of standard item buttons under its
-- scroll child. Their immediate parents carry bag IDs; buttons carry slot IDs.
local function paintEllesmere(root,depth)
  if not root or not root.GetChildren or (root.IsShown and not root:IsShown()) or depth>4 then return end
  for _,child in ipairs({root:GetChildren()}) do
    if child.IsShown and child:IsShown() then
      -- Ellesmere's skinned pooled buttons expose _textOverlay. Some clients
      -- report their native object type as Button rather than ItemButton.
      if child.GetID and child.GetParent and (child._textOverlay or (child.IsObjectType and child:IsObjectType("ItemButton"))) then
        local parent=child:GetParent();local bag=parent and parent.GetID and parent:GetID();local slot=child:GetID()
        local last=(Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or NUM_BAG_SLOTS or 4
        if type(bag)=="number" and bag>=0 and bag<=last and type(slot)=="number" and slot>0 then pcall(paint,child,bag,slot) end
      else paintEllesmere(child,depth+1) end
    end
  end
end
local function paintFrame(frame)
  if not frame or not frame.GetID then return end
  local bag=frame:GetID()
  if frame.EnumerateValidItems then
    for a,b in frame:EnumerateValidItems() do
      local button=type(b)=="table" and b or a
      if type(button)=="table" and button.GetID then
        local id=(button.GetBagID and button:GetBagID()) or bag
        if type(id)=="number" then pcall(paint,button,id,button:GetID()) end
      end
    end
  elseif frame.GetName and frame:GetName() then
    local name=frame:GetName()
    for i=1,(frame.size or 36) do
      local button=_G[name.."Item"..i]
      if button and button.IsShown and button:IsShown() and button.GetID then pcall(paint,button,bag,button:GetID()) end
    end
  end
end
-- ArkInventory reuses item buttons and may also show banks or offline bags.
-- Remember its live bag buttons so normal refreshes (Shift, exclusions and
-- trading visibility) can repaint them without waiting for a hover.
local arkButtons=setmetatable({},{__mode="k"})
local function paintArk(button,loc,arkBag,slot)
  local dot=dots[button]
  local ark=ArkInventory;local api=ark and ark.API;local locations=ark and ark.Const and ark.Const.Location
  if not api or not locations or (loc~=locations.Bag and loc~=locations.ReagentBag) or not api.LocationIsOffline then if dot then dot:Hide() end;return end
  local ok,offline=pcall(api.LocationIsOffline,loc)
  if not ok or offline~=false or (button.IsVisible and not button:IsVisible()) then if dot then dot:Hide() end;return end
  local bag=button.ARK_Data and button.ARK_Data.blizzard_id
  if type(bag)~="number" and api.getBlizzardBagIdFromWindowId then local mapped,value=pcall(api.getBlizzardBagIdFromWindowId,loc,arkBag);if mapped then bag=value end end
  local last=(Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or NUM_BAG_SLOTS or 4
  if type(bag)~="number" or bag<0 or bag>last or type(slot)~="number" or slot<1 then if dot then dot:Hide() end;return end
  pcall(paint,button,bag,slot)
end
local function refreshArk()
  local api=ArkInventory and ArkInventory.API
  if api and api.ItemFrameLoadedIterate then
    pcall(function()
      for _,button,loc,bag,slot in api.ItemFrameLoadedIterate() do
        if button then arkButtons[button]={loc,bag,slot} end
      end
    end)
  end
  for button,data in pairs(arkButtons) do paintArk(button,data[1],data[2],data[3]) end
end
local function refresh()
  pending=false
  for _,dot in pairs(dots) do dot:Hide() end
  if not markersVisible() then
    if Baganator and Baganator.API and Baganator.API.RequestItemButtonsRefresh then Baganator.API.RequestItemButtonsRefresh() end
    return
  end
  for i=1,(NUM_CONTAINER_FRAMES or 13) do
    local frame=_G["ContainerFrame"..i]
    if frame and frame.IsShown and frame:IsShown() then pcall(paintFrame,frame) end
  end
  local frame=_G.ContainerFrameCombinedBags
  if frame and frame.IsShown and frame:IsShown() then pcall(paintFrame,frame) end
  local ellesmere=_G.EUI_Bags or _G.EUI_MainBagFrame
  if ellesmere and ellesmere.IsShown and ellesmere:IsShown() then paintEllesmere(ellesmere._scrollChild,0) end
  refreshArk()
  if Baganator and Baganator.API and Baganator.API.RequestItemButtonsRefresh then Baganator.API.RequestItemButtonsRefresh() end
end
local function schedule()
  if pending then return end
  pending=true
  if C_Timer and C_Timer.After then C_Timer.After(.1,refresh) else refresh() end
end
core.RefreshBagRules=schedule
local arkHooked=false
local function setupArk()
  local api=ArkInventory and ArkInventory.API
  if arkHooked or not hooksecurefunc or not api or type(api.ItemFrameUpdated)~="function" then return end
  hooksecurefunc(api,"ItemFrameUpdated",function(button,loc,bag,slot)
    if not button then return end
    arkButtons[button]={loc,bag,slot};paintArk(button,loc,bag,slot)
  end)
  arkHooked=true
end
local baganatorRegistered=false
local baganatorViews=setmetatable({},{__mode="k"})
local function hookBaganatorView(frame)
  if not frame or not frame.HookScript or baganatorViews[frame] then return end
  baganatorViews[frame]=true
  frame:HookScript("OnShow",function() schedule() end)
end
local function hookBaganatorViews()
  for _,name in ipairs(UISpecialFrames or {}) do
    if type(name)=="string" and (name:match("^Baganator_SingleViewBackpackViewFrame") or name:match("^Baganator_CategoryViewBackpackViewFrame")) then
      hookBaganatorView(_G[name])
    end
  end
end
local function setupBaganator()
  if not Baganator or not Baganator.API or not Baganator.API.RegisterCornerWidget then return end
  if baganatorRegistered then hookBaganatorViews();return end
  Baganator.API.RegisterCornerWidget("Marketeer selling rules","marketeer_selling_rules",function(texture,details)
    if not markersVisible() then return false end
    if type(details)~="table" then return false end
    local link=details.itemLink;local id=details.itemID or (type(link)=="string" and tonumber(link:match("item:(%d+)")))
    if type(id)~="number" then return false end
    local location=details.itemLocation
    local bag=location and location.bagID;local slot=location and (location.slotIndex or location.slotID)
    if location and location.GetBagAndSlot and (type(bag)~="number" or type(slot)~="number") then local ok,b,s=pcall(location.GetBagAndSlot,location);if ok then bag,slot=b,s end end
    local rule=matchingRule(id,link,bag,slot)
    if not rule then return false end
    texture:SetColorTexture(rule.r or 1,rule.g or 1,rule.b or 1,1);return true
  end,function(button)
    local marker=button:CreateTexture(nil,"OVERLAY",nil,7);marker:SetSize(9,9);return marker
  end,{corner="bottom_left",priority=1})
  baganatorRegistered=true
  if Baganator.CallbackRegistry and Baganator.CallbackRegistry.RegisterCallback then
    Baganator.CallbackRegistry:RegisterCallback("BagShow",function() hookBaganatorViews();schedule() end)
    Baganator.CallbackRegistry:RegisterCallback("BackpackFrameChanged",function(_,frame) hookBaganatorView(frame);schedule() end)
  end
  hookBaganatorViews()
end
local hooked=setmetatable({},{__mode="k"})
local function hookFrames()
  if not hooksecurefunc then return end
  local function hook(frame)
    if frame and not hooked[frame] then
      if frame.UpdateItems then hooksecurefunc(frame,"UpdateItems",function() schedule() end) end
      if frame.HookScript then frame:HookScript("OnShow",function() schedule() end) end
      hooked[frame]=true
    end
  end
  for i=1,(NUM_CONTAINER_FRAMES or 13) do hook(_G["ContainerFrame"..i]) end
  hook(_G.ContainerFrameCombinedBags)
  local ellesmere=_G.EUI_Bags or _G.EUI_MainBagFrame
  if ellesmere and ellesmere.RefreshInventory and not hooked[ellesmere] then
    hooksecurefunc(ellesmere,"RefreshInventory",function() schedule() end);hooked[ellesmere]=true
    ellesmere:HookScript("OnShow",function() schedule() end)
  end
end
local function chooseColor(row)
  if not ColorPickerFrame then return end
  local r,g,b=row.r,row.g,row.b
  local function setColor()
    local nr,ng,nb=ColorPickerFrame:GetColorRGB()
    row.r,row.g,row.b=nr,ng,nb;row.swatch:SetColorTexture(nr,ng,nb,1)
  end
  local function cancel() row.r,row.g,row.b=r,g,b;row.swatch:SetColorTexture(r,g,b,1) end
  if ColorPickerFrame.SetupColorPickerAndShow then
    ColorPickerFrame:SetupColorPickerAndShow({r=r,g=g,b=b,hasOpacity=false,swatchFunc=setColor,cancelFunc=cancel})
  else
    ColorPickerFrame.func=setColor;ColorPickerFrame.cancelFunc=cancel;ColorPickerFrame.hasOpacity=false
    ColorPickerFrame:SetColorRGB(r,g,b);ColorPickerFrame:Show()
  end
end
local function buildWindow()
  if window then return end
  window=CreateFrame("Frame","MarketeerForeverBagRulesWindow",UIParent,"BackdropTemplate")
  core.RegisterEscapeFrame("MarketeerForeverBagRulesWindow")
  window:SetSize(610,420);window:SetPoint("CENTER");window:SetFrameStrata("DIALOG");window:SetMovable(true);window:EnableMouse(true);window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart",function(self) self:StartMoving() end);window:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
  window:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1});window:SetBackdropColor(.055,.065,.07,.98);window:SetBackdropBorderColor(.35,.42,.37,1)
  local title=window:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");title:SetPoint("TOPLEFT",16,-16);title:SetText("BAG SELLING RULES")
  local note=window:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");note:SetPoint("TOPLEFT",16,-43);note:SetPoint("TOPRIGHT",-16,-43);note:SetJustifyH("LEFT");note:SetText("AH premium is the AH price minus vendor value, divided by the AH price. The highest matching rule wins. When vendor pays more, the lowest Vendor rule applies.")
  local tradingOnly=CreateFrame("CheckButton",nil,window,"UICheckButtonTemplate");tradingOnly:SetSize(24,24);tradingOnly:SetPoint("TOPLEFT",16,-77)
  local tradingLabel=window:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");tradingLabel:SetPoint("LEFT",tradingOnly,"RIGHT",2,0);tradingLabel:SetText("Only show dots at the auction house or vendor (hold Shift to show)")
  tradingOnly:SetScript("OnClick",function(self) MarketeerForeverCoreDB=MarketeerForeverCoreDB or {};MarketeerForeverCoreDB.bagMarkersTradingOnly=self:GetChecked() and true or false;schedule() end)
  for i=1,6 do
    local row={};rows[i]=row
    local y=-110-(i-1)*39
    local label=window:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");label:SetPoint("TOPLEFT",20,y-5);label:SetText("AH premium over vendor >")
    row.threshold=CreateFrame("EditBox",nil,window,"InputBoxTemplate");row.threshold:SetSize(55,24);row.threshold:SetPoint("TOPLEFT",170,y);row.threshold:SetAutoFocus(false);row.threshold:SetMaxLetters(8)
    local suffix=window:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");suffix:SetPoint("TOPLEFT",230,y-5);suffix:SetText("% of AH")
    row.method=CreateFrame("Button",nil,window,"UIPanelButtonTemplate");row.method:SetSize(90,24);row.method:SetPoint("TOPLEFT",270,y)
    local menu=CreateFrame("Frame",nil,window,"BackdropTemplate");menu:SetSize(92,52);menu:SetPoint("TOPLEFT",row.method,"BOTTOMLEFT",0,-1);menu:SetFrameLevel(window:GetFrameLevel()+20);menu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1});menu:SetBackdropColor(.04,.06,.05,1);menu:SetBackdropBorderColor(.3,.5,.38,1);menu:Hide();row.methodMenu=menu
    for index,choice in ipairs({{"AH","auction"},{"Vendor","vendor"}}) do
      local label,value=choice[1],choice[2]
      local option=CreateFrame("Button",nil,menu,"UIPanelButtonTemplate");option:SetSize(88,24);option:SetPoint("TOPLEFT",menu,"TOPLEFT",2,-2-(index-1)*24);option:SetText(label)
      option:SetScript("OnClick",function() row.saleMethod=value;row.method:SetText(label.."  v");menu:Hide() end)
    end
    row.method:SetScript("OnClick",function() local show=not menu:IsShown();for _,other in ipairs(rows) do if other.methodMenu then other.methodMenu:Hide() end end;menu:SetShown(show) end)
    row.method:SetScript("OnEnter",function(self) if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:SetText("Bag value estimate");GameTooltip:AddLine("Choose whether items matching this rule use their AH price or vendor sell price in the estimated bag value. This does not sell items or change their dot color.",1,1,1,true);GameTooltip:Show() end end)
    row.method:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    row.color=CreateFrame("Button",nil,window,"BackdropTemplate");row.color:SetSize(27,24);row.color:SetPoint("TOPLEFT",375,y);row.color:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1});row.color:SetBackdropBorderColor(.8,.8,.8,1)
    row.swatch=row.color:CreateTexture(nil,"ARTWORK");row.swatch:SetPoint("TOPLEFT",2,-2);row.swatch:SetPoint("BOTTOMRIGHT",-2,2)
    row.color:SetScript("OnClick",function() chooseColor(row) end)
    row.junk=CreateFrame("CheckButton",nil,window,"UICheckButtonTemplate");row.junk:SetSize(24,24);row.junk:SetPoint("TOPLEFT",410,y)
    local junkLabel=window:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");junkLabel:SetPoint("LEFT",row.junk,"RIGHT",0,0);junkLabel:SetText("Junk")
    row.junk:SetScript("OnEnter",function(self) if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:SetText("Mark as junk");GameTooltip:AddLine("Items matching this rule can be sold using Marketeer's Sell junk button at a vendor. Excluded and quest items are skipped.",1,1,1,true);GameTooltip:Show() end end)
    row.junk:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    row.remove=CreateFrame("Button",nil,window,"UIPanelButtonTemplate");row.remove:SetSize(80,24);row.remove:SetPoint("TOPLEFT",505,y);row.remove:SetText("Remove")
    row.remove:SetScript("OnClick",function()
      for n=i,5 do local nextRow=rows[n+1];local dest=rows[n];dest.threshold:SetText(nextRow.threshold:GetText());dest.r,dest.g,dest.b=nextRow.r,nextRow.g,nextRow.b;dest.saleMethod=nextRow.saleMethod;dest.junk:SetChecked(nextRow.junk:GetChecked());dest.method:SetText((dest.saleMethod=="auction" and "AH" or "Vendor").."  v");dest.methodMenu:Hide();dest.swatch:SetColorTexture(dest.r,dest.g,dest.b,1) end
      local last=rows[6];last.threshold:SetText("");last.r,last.g,last.b=1,1,1;last.saleMethod="vendor";last.junk:SetChecked(false);last.method:SetText("Vendor  v");last.methodMenu:Hide();last.swatch:SetColorTexture(1,1,1,1)
    end)
  end
  status=window:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");status:SetPoint("BOTTOMLEFT",20,49);status:SetWidth(490);status:SetJustifyH("LEFT")
  local save=CreateFrame("Button",nil,window,"UIPanelButtonTemplate");save:SetSize(100,25);save:SetPoint("BOTTOMRIGHT",-126,14);save:SetText("Save rules")
  save:SetScript("OnClick",function()
    local nextRules={};local seen={}
    for _,row in ipairs(rows) do
      local value=row.threshold:GetText()
      if value~="" then
        local threshold=tonumber(value)
        if not threshold or threshold < -9900 or threshold>100 then status:SetText("Enter a percentage from -9900 to 100.");return end
        if seen[threshold] then status:SetText("Each percentage must be different.");return end
        seen[threshold]=true
        nextRules[#nextRules+1]={threshold=threshold,r=row.r,g=row.g,b=row.b,method=row.saleMethod or "vendor",junk=row.junk:GetChecked() and true or false}
      end
    end
    table.sort(nextRules,function(a,b) return a.threshold>b.threshold end)
    MarketeerForeverCoreDB=MarketeerForeverCoreDB or {};MarketeerForeverCoreDB.bagRules=nextRules;MarketeerForeverCoreDB.bagRulesVersion=3
    status:SetText("Rules saved. Bag value uses each matching rule's sale method.");schedule();if core.RefreshBagValue then core.RefreshBagValue() end
  end)
  local excluded=CreateFrame("Button",nil,window,"UIPanelButtonTemplate");excluded:SetSize(125,25);excluded:SetPoint("BOTTOMLEFT",20,14);excluded:SetText("Excluded items")
  excluded:SetScript("OnClick",function() if core.ShowBagExclusions then core.ShowBagExclusions() end end)
  local close=CreateFrame("Button",nil,window,"UIPanelButtonTemplate");close:SetSize(90,25);close:SetPoint("BOTTOMRIGHT",-22,14);close:SetText("Close");close:SetScript("OnClick",function() window:Hide() end)
  window:SetScript("OnShow",function()
    local saved=rules()
    tradingOnly:SetChecked(MarketeerForeverCoreDB and MarketeerForeverCoreDB.bagMarkersTradingOnly==true)
    for i,row in ipairs(rows) do local rule=saved[i];row.threshold:SetText(rule and tostring(rule.threshold) or "");row.r,row.g,row.b=rule and rule.r or 1,rule and rule.g or 1,rule and rule.b or 1;row.saleMethod=rule and ruleMethod(rule) or "vendor";row.junk:SetChecked(rule and rule.junk==true);row.method:SetText((row.saleMethod=="auction" and "AH" or "Vendor").."  v");row.methodMenu:Hide();row.swatch:SetColorTexture(row.r,row.g,row.b,1) end
    status:SetText("Each rule chooses AH or vendor for bag value. AH cut, binding and deposits are not included.")
  end)
  window:Hide()
end
function core.ToggleBagRules()
  buildWindow()
  if window:IsShown() then window:Hide() else window:Show() end
end
-- The vendor button only processes the specific stacks present when clicked.
-- Recheck each slot before selling: bags and prices can change while it runs.
local junkButton,sellingJunk,merchantSession=nil,false,0
local function junkCandidate(bag,slot)
  local c=C_Container
  if not c or not c.GetContainerItemInfo or not c.GetContainerItemQuestInfo then return nil end
  local info=c.GetContainerItemInfo(bag,slot)
  if not info or info.isLocked then return nil end
  local quest=c.GetContainerItemQuestInfo(bag,slot)
  if quest and (quest.isQuestItem or quest.questID) then return nil end
  local id=info.itemID or (info.hyperlink and tonumber(info.hyperlink:match("item:(%d+)")))
  local rule=id and matchingRule(id,info.hyperlink,bag,slot)
  if not rule or not rule.junk then return nil end
  return {bag=bag,slot=slot,id=id,link=info.hyperlink,count=info.stackCount or 1}
end
local function sellJunk()
  if sellingJunk or not merchantOpen or not MerchantFrame or not MerchantFrame:IsShown() then return end
  if (InCombatLockdown and InCombatLockdown()) or (CursorHasItem and CursorHasItem()) then print("Marketeer: Close combat and clear your cursor before selling junk.");return end
  local c=C_Container
  if not c or not c.GetContainerNumSlots or not c.UseContainerItem then return end
  local list={};local last=(Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or NUM_BAG_SLOTS or 4
  for bag=0,last do for slot=1,(c.GetContainerNumSlots(bag) or 0) do local item=junkCandidate(bag,slot);if item then list[#list+1]=item end end end
  if #list==0 then print("Marketeer: No eligible junk stacks found.");return end
  sellingJunk=true;junkButton:Disable();local index,confirmed,skipped,session=0,0,0,merchantSession
  local function step()
    if session~=merchantSession or not merchantOpen or not MerchantFrame:IsShown() or (InCombatLockdown and InCombatLockdown()) or (CursorHasItem and CursorHasItem()) then sellingJunk=false;junkButton:Enable();print("Marketeer: Junk selling stopped.");return end
    index=index+1;local original=list[index]
    if not original then sellingJunk=false;junkButton:Enable();print("Marketeer: "..confirmed.." junk stacks cleared; "..skipped.." not sold or changed. Check vendor buyback and remaining bags.");return end
    local attempts,polls=0,0
    local function trySale()
      if session~=merchantSession or not merchantOpen or not MerchantFrame:IsShown() or (InCombatLockdown and InCombatLockdown()) or (CursorHasItem and CursorHasItem()) then sellingJunk=false;junkButton:Enable();print("Marketeer: Junk selling stopped.");return end
      local info=c.GetContainerItemInfo(original.bag,original.slot)
      local id=info and (info.itemID or (info.hyperlink and tonumber(info.hyperlink:match("item:(%d+)"))))
      if not info or id~=original.id or info.hyperlink~=original.link or (info.stackCount or 1)~=original.count then
        if attempts>0 then confirmed=confirmed+1 else skipped=skipped+1 end;step();return
      end
      if polls>=15 then skipped=skipped+1;step();return end
      if not info.isLocked and polls%5==0 then
        local current=junkCandidate(original.bag,original.slot)
        if not current then skipped=skipped+1;step();return end
        local ok=pcall(c.UseContainerItem,original.bag,original.slot)
        if not ok then sellingJunk=false;junkButton:Enable();print("Marketeer: Junk selling stopped because the game blocked the action.");return end
        attempts=attempts+1
      end
      polls=polls+1
      C_Timer.After(.15,trySale)
    end
    trySale()
  end
  if not C_Timer or not C_Timer.After then sellingJunk=false;junkButton:Enable();print("Marketeer: Junk selling is unavailable on this client.");return end
  step()
end
local function showJunkButton()
  if not MerchantFrame then return end
  if not junkButton then
    junkButton=CreateFrame("Button",nil,UIParent,"UIPanelButtonTemplate");junkButton:SetSize(100,24);junkButton:SetFrameStrata("DIALOG")
    if MerchantFrameTab2 then junkButton:SetPoint("LEFT",MerchantFrameTab2,"RIGHT",8,0) else junkButton:SetPoint("TOPLEFT",MerchantFrame,"BOTTOMLEFT",210,-3) end
    junkButton:SetText("Sell junk")
    junkButton:SetScript("OnClick",sellJunk)
    junkButton:SetScript("OnEnter",function(self) if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Sell Marketeer junk");GameTooltip:AddLine("Sell bag stacks matching rules checked as junk. Excluded and quest items are skipped.",1,1,1,true);GameTooltip:Show() end end)
    junkButton:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
  end
  junkButton:Show()
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","ADDON_LOADED","BAG_UPDATE_DELAYED","GET_ITEM_INFO_RECEIVED","PLAYER_REGEN_ENABLED","AUCTION_HOUSE_SHOW","AUCTION_HOUSE_CLOSED","MERCHANT_SHOW","MERCHANT_CLOSED","MODIFIER_STATE_CHANGED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event,key)
  if event=="MODIFIER_STATE_CHANGED" and key~="LSHIFT" and key~="RSHIFT" then return end
  if event=="PLAYER_LOGIN" or event=="ADDON_LOADED" then
    hookFrames();setupBaganator();setupArk()
    if event=="PLAYER_LOGIN" then auctionOpen=AuctionHouseFrame and AuctionHouseFrame.IsShown and AuctionHouseFrame:IsShown() or false;merchantOpen=MerchantFrame and MerchantFrame.IsShown and MerchantFrame:IsShown() or false;if merchantOpen then showJunkButton() end end
  elseif event=="AUCTION_HOUSE_SHOW" then auctionOpen=true
  elseif event=="AUCTION_HOUSE_CLOSED" then auctionOpen=false
  elseif event=="MERCHANT_SHOW" then merchantOpen=true;showJunkButton()
  elseif event=="MERCHANT_CLOSED" then merchantOpen=false;merchantSession=merchantSession+1;if junkButton then junkButton:Hide() end end
  schedule()
end)
core.Subscribe(schedule)
