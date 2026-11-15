-- Show the last scanned unit price on hover and expanded valuation on Shift.
local function money(n)
  local c=math.floor(n*100+0.5)/100;local g=math.floor(c/10000);local s=math.floor(c%10000/100);c=c%100
  local gold="|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t"
  local silver="|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t"
  local copper="|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t"
  local parts={}
  if g>0 then parts[#parts+1]=g..gold end
  if s>0 then parts[#parts+1]=s..silver end
  if c>0 or #parts==0 then parts[#parts+1]=string.format("%.2f",c):gsub("0+$",""):gsub("%.$","")..copper end
  return table.concat(parts," ")
end
local function merchantDetails(tooltip,id)
  local owner=tooltip.GetOwner and tooltip:GetOwner()
  if not owner or not MerchantFrame or not MerchantFrame.IsShown or not MerchantFrame:IsShown() then return nil end
  local name=owner.GetName and owner:GetName()
  local merchant=name and tonumber(name:match("^MerchantItem(%d+)ItemButton$"))
  local parent=owner.GetParent and owner:GetParent()
  if not merchant and parent and parent.GetName then merchant=tonumber((parent:GetName() or ""):match("^MerchantItem(%d+)$")) end
  local cursor=owner;local belongs=false
  for _=1,8 do if not cursor then break end;if cursor==MerchantFrame then belongs=true;break end;local n=cursor.GetName and cursor:GetName();if n and n:match("^MerchantItem%d+") then belongs=true;break end;cursor=cursor.GetParent and cursor:GetParent() end
  if not belongs then return nil end
  if merchant and GetMerchantItemID and id and GetMerchantItemID(merchant)~=id then merchant=nil end
  if not merchant and id and GetMerchantNumItems and GetMerchantItemID then
    local count=GetMerchantNumItems() or 0
    for i=1,count do if GetMerchantItemID(i)==id then if merchant then return nil end;merchant=i end end
  end
  if not merchant then return nil end
  if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
    local ok,info=pcall(C_MerchantFrame.GetItemInfo,merchant)
    if ok and type(info)=="table" and type(info.stackCount)=="number" and info.stackCount>0 then return info.stackCount,info.price end
  end
  if GetMerchantItemInfo then local _,_,price,quantity=GetMerchantItemInfo(merchant);if type(quantity)=="number" and quantity>0 then return quantity,price end end
  return nil
end
MarketeerForeverCore.MerchantDetails=merchantDetails
local function stackCount(tooltip,id)
  local count,cost=merchantDetails(tooltip,id)
  if count then return count,cost,true end
  local owner=tooltip.GetOwner and tooltip:GetOwner()
  if not owner then return nil end
  if AuctionHouseFrame then
    for _,key in ipairs({"CommoditiesSellFrame","ItemSellFrame"}) do
      local frame=AuctionHouseFrame[key]
      local cursor=owner
      for _=1,8 do
        if not cursor then break end
        if frame and cursor==frame then
          local location=frame.GetItem and frame:GetItem()
          local itemID=location and C_Item and C_Item.GetItemID and C_Item.GetItemID(location)
          local quantity=frame.GetQuantity and frame:GetQuantity()
          if itemID==id and type(quantity)=="number" and quantity>0 then return quantity,nil,false,true end
          break
        end
        cursor=cursor.GetParent and cursor:GetParent()
      end
    end
  end
  -- Forever bank buttons expose tab and slot separately, not GetBagID/GetID.
  if owner.GetBankTabID and owner.GetContainerSlotID and C_Container and C_Container.GetContainerItemInfo then
    local okBag,bank=pcall(owner.GetBankTabID,owner)
    local okSlot,bankSlot=pcall(owner.GetContainerSlotID,owner)
    if okBag and okSlot and type(bank)=="number" and type(bankSlot)=="number" then
      local ok,info=pcall(C_Container.GetContainerItemInfo,bank,bankSlot)
      local itemID=ok and type(info)=="table" and (info.itemID or (info.hyperlink and tonumber(info.hyperlink:match("item:(%d+)"))))
      if itemID==id and type(info.stackCount)=="number" and info.stackCount>0 then return info.stackCount end
    end
  end
  -- Some item buttons provide an ItemLocation instead of container IDs.
  if owner.GetItemLocation and C_Item and C_Item.GetItemID and C_Item.GetStackCount then
    local ok,location=pcall(owner.GetItemLocation,owner)
    if ok and location then
      local idOK,itemID=pcall(C_Item.GetItemID,location)
      if idOK and itemID==id then
        local countOK,quantity=pcall(C_Item.GetStackCount,location)
        if countOK and type(quantity)=="number" and quantity>0 then return quantity end
      end
    end
  end
  local bag=owner.GetBagID and owner:GetBagID()
  local slot=owner.GetID and owner:GetID()
  local name=owner.GetName and owner:GetName()
  -- The main bank uses its own item buttons rather than a container frame.
  if name and name:match("^BankFrameItem%d+$") then
    bag=(Enum and Enum.BagIndex and Enum.BagIndex.Bank) or BANK_CONTAINER or -1
  end
  local parent=owner.GetParent and owner:GetParent()
  if type(bag)~="number" and parent and parent.GetName and (parent:GetName() or ""):match("^ContainerFrame%d+") then bag=parent.GetID and parent:GetID() end
  if type(bag)=="number" and type(slot)=="number" and C_Container and C_Container.GetContainerItemInfo then
    local info=C_Container.GetContainerItemInfo(bag,slot)
    if type(info)=="table" and (not info.itemID or info.itemID==id) and type(info.stackCount)=="number" and info.stackCount>0 then return info.stackCount end
  end
  return nil
end
MarketeerForeverCore.ItemStackContext=stackCount
local function vendorSellValue(id,link)
  local getInfo=(C_Item and C_Item.GetItemInfo) or GetItemInfo
  if getInfo then
    local info={pcall(getInfo,link or id)}
    if info[1] and type(info[12])=="number" then return info[12] end
  end
  -- Catalog values are keyed by item ID and may differ for a modified item.
  if not link then
    local catalog=MarketeerForeverMarketDB and MarketeerForeverMarketDB.itemCatalog
    local item=catalog and (catalog[tostring(id)] or catalog[id])
    if item and type(item.vendorSell)=="number" then return item.vendorSell end
  end
  if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID,id) end
end
-- These are observed vendor offers, not a guarantee a vendor is accessible or stocked.
local vendorBuyIndex
local function vendorBuyReference(id)
  if not vendorBuyIndex then
    if type(MarketeerForeverMarketVendorData)~="table" then return nil end
    vendorBuyIndex={}
    for _,offer in ipairs(MarketeerForeverMarketVendorData) do
      local item,price,pack=offer[1],offer[4],offer[5]
      if type(item)=="number" and type(price)=="number" and price>0 and type(pack)=="number" and pack>0 then
        local unit=price/pack
        if not vendorBuyIndex[item] or unit<vendorBuyIndex[item] then vendorBuyIndex[item]=unit end
      end
    end
  end
  return vendorBuyIndex[id]
end
-- A separate, non-interactive panel keeps market trends out of the item tooltip.
local trendPanel
local function hideTrendPanel() if trendPanel then trendPanel:Hide() end end
local function placeTrendPanel(p,owner)
  if not UIParent or not owner.GetLeft or not owner:GetLeft() then return end
  local uiScale=UIParent:GetEffectiveScale();local function bounds(f)
    if not f or not f.IsShown or not f:IsShown() or not f.GetLeft or not f:GetLeft() then return end
    local ratio=f:GetEffectiveScale()/uiScale
    return f:GetLeft()*ratio,f:GetRight()*ratio,f:GetTop()*ratio,f:GetBottom()*ratio
  end
  local left,right,top,bottom=bounds(owner);if not left then return end
  local leftFrame,rightFrame,topFrame,bottomFrame=owner,owner,owner,owner
  for _,f in ipairs({ShoppingTooltip1,ShoppingTooltip2}) do
    local l,r,t,b=bounds(f)
    if l then
      if l<left then left,leftFrame=l,f end;if r>right then right,rightFrame=r,f end
      if t>top then top,topFrame=t,f end;if b<bottom then bottom,bottomFrame=b,f end
    end
  end
  local width,height=p:GetWidth(),p:GetHeight();local sw,sh=UIParent:GetWidth(),UIParent:GetHeight()
  p:ClearAllPoints()
  if right+8+width<=sw then p:SetPoint("TOPLEFT",rightFrame,"TOPRIGHT",8,0)
  elseif left-8-width>=0 then p:SetPoint("TOPRIGHT",leftFrame,"TOPLEFT",-8,0)
  elseif bottom-8-height>=0 then p:SetPoint("TOPLEFT",bottomFrame,"BOTTOMLEFT",0,-8)
  else p:SetPoint("BOTTOMLEFT",topFrame,"TOPLEFT",0,8) end
end
local function comparisonState()
  return (ShoppingTooltip1 and ShoppingTooltip1:IsShown() and 1 or 0)+(ShoppingTooltip2 and ShoppingTooltip2:IsShown() and 2 or 0)
end
local function showTrendPanel(owner,id,trend,current,currentAge,currentSource,now)
  if not trendPanel then
    local p=CreateFrame("Frame",nil,UIParent,"BackdropTemplate");trendPanel=p
    p:SetSize(265,152);p:SetFrameStrata("TOOLTIP");p:SetClampedToScreen(true);p:EnableMouse(false)
    p:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    p:SetBackdropColor(.045,.055,.065,.97);p:SetBackdropBorderColor(.34,.40,.45,1)
    p.title=p:CreateFontString(nil,"OVERLAY","GameFontNormal");p.title:SetPoint("TOPLEFT",p,"TOPLEFT",10,-9);p.title:SetText("Market price trends")
    p.basis=p:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");p.basis:SetPoint("TOPLEFT",p,"TOPLEFT",10,-27);p.basis:SetText("Low buyouts | AHledger (ahledger.com)")
    p.currentLabel=p:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");p.currentLabel:SetPoint("TOPLEFT",p,"TOPLEFT",10,-44)
    p.currentValue=p:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");p.currentValue:SetPoint("TOPRIGHT",p,"TOPRIGHT",-10,-44);p.currentValue:SetJustifyH("RIGHT")
    p.rows={}
    for i=1,3 do
      local left=p:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");left:SetPoint("TOPLEFT",p,"TOPLEFT",10,-56-i*17)
      local right=p:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");right:SetPoint("TOPRIGHT",p,"TOPRIGHT",-10,-56-i*17);right:SetJustifyH("RIGHT")
      p.rows[i]={left=left,right=right}
    end
    p.footer=p:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");p.footer:SetPoint("BOTTOMLEFT",p,"BOTTOMLEFT",10,8)
    p:SetScript("OnUpdate",function(self,elapsed)
      local o=self.trendOwner
      if not IsShiftKeyDown or not IsShiftKeyDown() then self:Hide();return end
      -- Auction-house tooltips may briefly hide or change their item while
      -- refreshing. Wait for that transition to settle before hiding the panel.
      local unavailable=not o or not o.IsShown or not o:IsShown()
      if not unavailable and o.GetItem then local _,link=o:GetItem();local currentId=type(link)=="string" and tonumber(link:match("item:(%d+)"));unavailable=currentId and currentId~=self.trendItem end
      if unavailable then
        self.ownerMissingFor=(self.ownerMissingFor or 0)+(elapsed or 0)
        if self.ownerMissingFor>=.2 then self:Hide() end
        return
      end
      self.ownerMissingFor=0
      local state=comparisonState()
      if state~=self.pendingComparison then self.pendingComparison=state;self.comparisonElapsed=0
      elseif state~=self.placedComparison then
        self.comparisonElapsed=(self.comparisonElapsed or 0)+(elapsed or 0)
        if self.comparisonElapsed>=.15 then placeTrendPanel(self,o);self.placedComparison=state end
      end
    end)
  end
  local p=trendPanel
  if p.trendOwner~=owner or p.trendItem~=id or not p:IsShown() then
    p.trendOwner=owner;p.trendItem=id;p.ownerMissingFor=0;p.pendingComparison=comparisonState();p.placedComparison=p.pendingComparison;p.comparisonElapsed=0;placeTrendPanel(p,owner)
  end
  p.currentLabel:SetText(current and (currentSource..(currentAge and (" ("..currentAge.."m ago)") or " (age ?)")) or "Latest AH price")
  p.currentValue:SetText(current and money(current) or "Unavailable")
  local periods={{"24 hours",trend and trend.p24},{"48 hours",trend and trend.p48},{"14 days",trend and trend.p14}}
  for i,period in ipairs(periods) do
    p.rows[i].left:SetText(period[1])
    local price=period[2];local value=price and money(price) or (trend and "Building history" or "Unavailable")
    if price and type(current)=="number" and current>0 then
      local change=(current/price-1)*100
      local color=change>0 and "|cff46e06f" or change<0 and "|cffff5555" or "|cffdddddd"
      value=value.."  "..color..string.format("(%+.1f%%)",change).."|r"
    end
    p.rows[i].right:SetText(value)
  end
  p.footer:SetText(trend and ("Latest AH vs period | data "..math.max(0,math.floor((now-trend.observed)/60)).."m ago") or "Update data for this market")
  p:Show()
end
local function addValue(tooltip,data)
  if tooltip.IsForbidden and tooltip:IsForbidden() then return end
  local link;if tooltip.GetItem then local _;_,link=tooltip:GetItem() end
  local id=type(link)=="string" and tonumber(link:match("item:(%d+)")) or (data and data.id)
  if not id then if tooltip==GameTooltip then hideTrendPanel() end;return end
  if tooltip==GameTooltip and MarketeerForeverCore.RefreshBagRuleForTooltip then MarketeerForeverCore.RefreshBagRuleForTooltip(tooltip,id) end
  local market=MarketeerForeverCore.Market();local book=market and MarketeerForeverCoreDB and MarketeerForeverCoreDB.prices and MarketeerForeverCoreDB.prices[market]
  local row=book and book.items and book.items[id];local count,cost,isMerchant,isAuction=stackCount(tooltip,id)
  local now=(GetServerTime and GetServerTime()) or time()
  local scanAge=book and type(book.observed)=="number" and math.max(0,math.floor((now-book.observed)/60))
  local priceAge,currentPrice,currentAge,currentSource
  local function pair(label,value)
    if tooltip.AddDoubleLine then tooltip:AddDoubleLine(label,value,.45,.9,.7,1,1,1)
    else tooltip:AddLine(label.."  "..value,.45,.9,.7) end
  end
  local captured=MarketeerForeverFarmLookup and MarketeerForeverFarmLookup.items and MarketeerForeverFarmLookup.items[id]
  if captured and (#captured.drops+#(captured.sources or {}))>0 then pair("Recorded sources",tostring(#captured.drops+#(captured.sources or {})).." | /marketeer drops "..id)
  else pair("Monster sources","No captured drop table") end
  if tooltip==GameTooltip then
    tooltip:AddLine("Bag Alt+Right-click: sources or recipe",.65,.85,.7,true)
    tooltip:AddLine("Alt+Left-click: price history  |  Hold Shift: market details",.65,.85,.7,true)
  end
  local sell=vendorSellValue(id,link)
  pair("Vendor sell / unit",sell and money(sell) or "Loading...")
  if isMerchant and type(cost)=="number" and cost>0 and count and count>0 then
    pair("Vendor buy / unit",money(cost/count))
  else
    local buy=vendorBuyReference(id)
    pair("Vendor buy / unit (ref)",buy and money(buy) or "--")
  end
  if row and type(row.price)=="number" and row.price>0 then
    local observed=type(row.observed)=="number" and math.max(0,math.floor((now-row.observed)/60)) or scanAge
    currentPrice,currentAge,currentSource=row.price,observed,"Last AH scan"
    pair("AH / unit"..(observed and (" ("..observed.."m ago)") or ""),money(row.price))
  else
    local reference=MarketeerForeverAPI and MarketeerForeverAPI.GetPrice(id)
    if reference and type(reference.minBuyout)=="number" and reference.minBuyout>0 then
      local minutes=type(reference.updated)=="number" and math.max(0,math.floor((now-reference.updated)/60))
      currentPrice,currentAge,currentSource=reference.minBuyout,minutes,"AH reference"
      pair("AH reference / unit"..(minutes and (" ("..minutes.."m ago)") or ""),money(reference.minBuyout))
    else pair("AH / unit","--") end
  end
  if not IsShiftKeyDown or not IsShiftKeyDown() then if tooltip==GameTooltip then hideTrendPanel() end;tooltip:Show();return end
  local trend=MarketeerForeverAPI and MarketeerForeverAPI.GetTrend and MarketeerForeverAPI.GetTrend(id)
  if row and type(row.price)=="number" and row.price>0 then
    priceAge=type(row.observed)=="number" and math.max(0,math.floor((now-row.observed)/60)) or scanAge
    if count then
      local gross=row.price*count;local net=math.floor(gross*95/100)
      pair((isAuction and "Auction quantity (" or "Stack price (")..count..")",money(gross))
      pair("After 5% AH cut",money(net))
      if isMerchant and type(cost)=="number" and cost>=0 then
        pair("Vendor pack cost",money(cost))
        local gain=net-cost
        pair("Est. pack profit",(gain<0 and "-" or "")..money(math.abs(gain)))
      end
    else tooltip:AddLine("Stack size unavailable",.8,.8,.8) end
    pair("Listed (last scan)",(not row.carried and type(row.quantity)=="number") and tostring(row.quantity) or "--")
  else tooltip:AddLine("Marketeer: no matching scan price. Scan the auction house.",1,.7,.3) end
  local activity=MarketeerForeverAPI and MarketeerForeverAPI.GetPrice(id)
  local info=MarketeerForeverAPI and MarketeerForeverAPI.GetTableInfo()
  if activity and type(activity.soldPerDay)=="number" then
    local minutes=info and type(info.updated)=="number" and math.max(0,math.floor((((GetServerTime and GetServerTime()) or time())-info.updated)/60))
    pair("Est. sales / day",tostring(activity.soldPerDay)..(minutes and (" ("..minutes.."m ago)") or " (age ?)") )
    local ageText="Scan: "..(scanAge and (scanAge.."m ago") or "age ?")
    if row and row.carried then ageText="Price: "..(priceAge and (priceAge.."m ago") or "age ?").." | "..ageText end
    tooltip:AddLine(ageText.." | Prices from AHledger (ahledger.com)",.7,.8,.75)
  elseif scanAge then
    local ageText="Scan: "..scanAge.."m ago"
    if row and row.carried then ageText="Price: "..(priceAge and (priceAge.."m ago") or "age ?").." | "..ageText end
    tooltip:AddLine(ageText.." | Sales data unavailable",.7,.8,.75)
  end
  tooltip:Show()
  if tooltip==GameTooltip then showTrendPanel(tooltip,id,trend,currentPrice,currentAge,currentSource,now) end
end
local function itemTooltipCallback(tooltip,data)
  if securecallfunction then securecallfunction(addValue,tooltip,data) else addValue(tooltip,data) end
end
if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,itemTooltipCallback)
elseif GameTooltip and GameTooltip.HookScript then GameTooltip:HookScript("OnTooltipSetItem",itemTooltipCallback) end
local f=CreateFrame("Frame");f:RegisterEvent("MODIFIER_STATE_CHANGED");f:RegisterEvent("GET_ITEM_INFO_RECEIVED");f:SetScript("OnEvent",function(_,event,key,success)
  if not GameTooltip or not GameTooltip.IsShown or not GameTooltip:IsShown() or not GameTooltip.RefreshData or not GameTooltip.GetItem then return end
  if GameTooltip.IsForbidden and GameTooltip:IsForbidden() then return end
  local ok,_,link=pcall(GameTooltip.GetItem,GameTooltip)
  local itemID=ok and type(link)=="string" and tonumber(link:match("item:(%d+)"))
  if not itemID then return end
  if event=="MODIFIER_STATE_CHANGED" then
    if key~="LSHIFT" and key~="RSHIFT" then return end
  else
    if not success or itemID~=key then return end
  end
  if securecallfunction then securecallfunction(GameTooltip.RefreshData,GameTooltip) else GameTooltip:RefreshData() end
end)
