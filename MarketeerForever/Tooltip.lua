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
  if owner.marketeerResultItemID==id and type(owner.marketeerResultQuantity)=="number" and owner.marketeerResultQuantity>0 then return owner.marketeerResultQuantity end
  -- An owned-auction icon represents its listing's quantity rather than a bag slot.
  if owner.marketeerAuctionItemID==id and type(owner.marketeerAuctionQuantity)=="number" and owner.marketeerAuctionQuantity>0 then return owner.marketeerAuctionQuantity,nil,false,true end
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
function MarketeerForeverCore.ShowResultItemTooltip(owner,item)
  if not (GameTooltip and owner and type(item)=='table' and type(item.id)=='number') then return end
  local recipe=item.recipe
  local quantity=recipe and recipe.yieldMin or item.stack
  owner.marketeerResultItemID=item.id;owner.marketeerResultQuantity=type(quantity)=='number' and quantity>0 and quantity or nil
  GameTooltip:SetOwner(owner,'ANCHOR_RIGHT');GameTooltip:SetHyperlink('item:'..item.id);GameTooltip:Show()
end
function MarketeerForeverCore.HideResultItemTooltip(owner)
  owner.marketeerResultItemID=nil;owner.marketeerResultQuantity=nil
  if GameTooltip and (not GameTooltip.GetOwner or GameTooltip:GetOwner()==owner) then GameTooltip:Hide() end
end
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
local function profitForCost(cost,count,scanPrice)
  if type(cost)~='number' or cost<0 then return nil,nil,nil end
  local unit=math.max(1,math.ceil((math.floor(cost)+1)/(count*.95)))
  while math.floor(unit*count*.95)<=cost do unit=unit+1 end
  while unit>1 and math.floor((unit-1)*count*.95)>cost do unit=unit-1 end
  return type(scanPrice)=='number' and scanPrice>0 and math.floor(scanPrice*count*.95)-cost or nil,unit,math.floor(unit*count*.95)-cost
end
-- Costs are estimates for acquiring enough units, not the player's historical cost.
local function profitEstimate(id,count,merchantCost,book,scanPrice)
  count=type(count)=='number' and count>0 and math.floor(count) or 1
  local result={quantity=count}
  if type(merchantCost)=='number' and merchantCost>=0 then result.vendor=merchantCost;result.vendorLabel='Current vendor pack'
  elseif MarketeerForeverCore.OwnedVendorCost then
    local offer=MarketeerForeverCore.OwnedVendorCost(id,count)
    if offer and type(offer.cost)=='number' and offer.cost>=0 then result.vendor=offer.cost;result.vendorLabel=offer.observed and 'Vendor observed' or 'Vendor reference' end
  end
  local recipes=MarketeerForeverCraftCraftCatalog and MarketeerForeverCraftCraftCatalog.recipes
  for _,recipe in pairs(recipes or {}) do
    if recipe.output==id and type(recipe.yieldMin)=='number' and recipe.yieldMin>0 and type(recipe.materials)=='table' and #recipe.materials>0 then
      local cost,valid=0,true
      for _,material in ipairs(recipe.materials) do
        local materialRow=book and book.items and book.items[material.id]
        if not (materialRow and not materialRow.carried and type(materialRow.price)=='number' and materialRow.price>0 and type(material.quantity)=='number' and material.quantity>0) then valid=false;break end
        cost=cost+materialRow.price*material.quantity
      end
      if valid then
        local crafts=math.ceil(count/recipe.yieldMin);local total=cost*crafts
        if not result.craft or total<result.craft then result.craft=total;result.craftPerCraft=cost;result.craftLabel=recipe.name;result.craftYield=recipe.yieldMin;result.crafts=crafts end
      end
    end
  end
  if result.vendor~=nil and (result.craft==nil or result.vendor<=result.craft) then result.cost=result.vendor;result.basis=result.vendorLabel
  elseif result.craft~=nil then result.cost=result.craft;result.basis='Craft estimate' end
  if result.cost~=nil then
    local minNet=math.floor(result.cost)+1
    local unit=math.max(1,math.ceil(minNet/(count*.95)))
    while math.floor(unit*count*.95)<=result.cost do unit=unit+1 end
    while unit>1 and math.floor((unit-1)*count*.95)>result.cost do unit=unit-1 end
    result.profitableUnit=unit;result.profitableProfit=math.floor(unit*count*.95)-result.cost
    if type(scanPrice)=='number' and scanPrice>0 then result.lowProfit=math.floor(scanPrice*count*.95)-result.cost end
  end
  return result
end
MarketeerForeverCore.TooltipProfitEstimate=profitEstimate
-- A separate, non-interactive panel keeps market trends out of the item tooltip.
local trendPanel,recipePanel
local function hideTrendPanel() if trendPanel then trendPanel:Hide() end;if recipePanel then recipePanel:Hide() end end
local function knownResourceRecipes(itemID)
  local realm=GetRealmName and GetRealmName();local player=UnitName and UnitName('player')
  local books=realm and player and MarketeerForeverCraftDB and MarketeerForeverCraftDB.crafting and MarketeerForeverCraftDB.crafting[realm..'|'..player]
  local catalog=MarketeerForeverCraftCraftCatalog and MarketeerForeverCraftCraftCatalog.recipes
  local found={}
  for profession,book in pairs(books or {}) do
    for recipeID,saved in pairs(type(book)=='table' and book.recipes or {}) do
      local recipe=(catalog and (catalog[recipeID] or catalog[tonumber(recipeID)])) or saved
      for _,material in ipairs(type(recipe)=='table' and recipe.materials or {}) do
        if material.id==itemID then found[#found+1]={profession=profession,name=recipe.name or (type(saved)=='table' and saved.name) or ('Recipe #'..tostring(recipeID))};break end
      end
    end
  end
  table.sort(found,function(a,b) if a.profession~=b.profession then return a.profession<b.profession end;return a.name<b.name end)
  return found
end
MarketeerForeverCore.KnownResourceRecipes=knownResourceRecipes
local function showRecipePanel(owner,itemID)
  local recipes=knownResourceRecipes(itemID)
  if #recipes==0 then if recipePanel then recipePanel:Hide() end;return end
  if not recipePanel then
    local p=CreateFrame('Frame',nil,UIParent,'BackdropTemplate');recipePanel=p
    p:SetSize(240,280);p:SetFrameStrata('TOOLTIP');p:SetClampedToScreen(true);p:EnableMouse(true);p:EnableMouseWheel(true)
    p:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1});p:SetBackdropColor(.035,.055,.052,.98);p:SetBackdropBorderColor(.31,.66,.47,1)
    p.title=p:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');p.title:SetPoint('TOPLEFT',p,'TOPLEFT',12,-12);p.title:SetText('KNOWN RECIPES')
    p.lines={};for i=1,12 do local line=p:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');line:SetPoint('TOPLEFT',p,'TOPLEFT',12,-30-(i-1)*18);line:SetWidth(216);line:SetJustifyH('LEFT');line:SetWordWrap(false);p.lines[i]=line end
    p.footer=p:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');p.footer:SetPoint('BOTTOMLEFT',p,'BOTTOMLEFT',12,9)
    p:SetScript('OnMouseWheel',function(self,delta)self.offset=math.max(0,math.min(math.max(0,#self.entries-#self.lines),(self.offset or 0)-delta*3));self:Render()end)
    function p:Render()
      for i,line in ipairs(self.lines) do local entry=self.entries[(self.offset or 0)+i];if entry then line:SetText(entry);line:Show() else line:Hide() end end
      self.footer:SetText(#self.entries>#self.lines and 'Scroll for more recipes' or 'Captured known recipes')
    end
  end
  local entries,last={},nil
  for _,recipe in ipairs(recipes) do
    if recipe.profession~=last then last=recipe.profession;entries[#entries+1]='|cffffd100'..last..'|r' end
    entries[#entries+1]='  '..recipe.name
  end
  local p=recipePanel;p.entries=entries;if p.itemID~=itemID then p.offset=0 end;p.itemID=itemID;p:Render()
  p:SetHeight(50+math.min(#entries,#p.lines)*18);p:ClearAllPoints()
  local right=owner.GetRight and owner:GetRight();local scale=owner.GetEffectiveScale and owner:GetEffectiveScale();local uiScale=UIParent.GetEffectiveScale and UIParent:GetEffectiveScale();local screenWidth=UIParent.GetWidth and UIParent:GetWidth()
  if type(right)=='number' and type(scale)=='number' and type(uiScale)=='number' and type(screenWidth)=='number' and right*scale/uiScale+248>screenWidth then p:SetPoint('TOPRIGHT',owner,'TOPLEFT',-8,0)
  else p:SetPoint('TOPLEFT',owner,'TOPRIGHT',8,0) end
  p:Show()
end
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
local function showTrendPanel(owner,id,trend,current,currentAge,currentSource,now,details)
  if not trendPanel then
    local p=CreateFrame("Frame",nil,UIParent,"BackdropTemplate");trendPanel=p
    p:SetSize(365,600);p:SetFrameStrata("TOOLTIP");p:SetClampedToScreen(true);p:EnableMouse(false)
    p:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    p:SetBackdropColor(.035,.055,.052,.98);p:SetBackdropBorderColor(.31,.66,.47,1)
    p.headings={};p.badges={}
    for i=1,4 do
      p.headings[i]=p:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
      local badge=CreateFrame('Frame',nil,p,'BackdropTemplate');badge:SetSize(96,16)
      badge:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1})
      badge.label=badge:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');badge.label:SetPoint('CENTER',badge,'CENTER',0,0)
      p.badges[i]=badge
    end
    p.rows={}
    for i=1,22 do
      local left=p:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");left:SetWidth(180);left:SetJustifyH('LEFT');left:SetWordWrap(false)
      local right=p:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");right:SetWidth(165);right:SetJustifyH("RIGHT");right:SetWordWrap(false)
      p.rows[i]={left=left,right=right}
    end
    p.footer=p:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");p.footer:SetPoint("BOTTOMLEFT",p,"BOTTOMLEFT",12,8);p.footer:SetText('Whole packs / crafts; min yield; deposits excluded')
    p:SetScript("OnUpdate",function(self,elapsed)
      local o=self.trendOwner
      if not IsShiftKeyDown or not IsShiftKeyDown() then hideTrendPanel();return end
      -- Auction-house tooltips may briefly hide or change their item while
      -- refreshing. Wait for that transition to settle before hiding the panel.
      local unavailable=not o or not o.IsShown or not o:IsShown()
      if not unavailable and o.GetItem then local _,link=o:GetItem();local currentId=type(link)=="string" and tonumber(link:match("item:(%d+)"));unavailable=currentId and currentId~=self.trendItem end
      if unavailable and recipePanel and recipePanel.IsMouseOver and recipePanel:IsMouseOver() then self.ownerMissingFor=0;return end
      if unavailable then
        self.ownerMissingFor=(self.ownerMissingFor or 0)+(elapsed or 0)
        if self.ownerMissingFor>=.2 then hideTrendPanel() end
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
    p.trendOwner=owner;p.trendItem=id;p.ownerMissingFor=0;p.pendingComparison=comparisonState();p.placedComparison=p.pendingComparison;p.comparisonElapsed=0
  end
  local function signed(value) if type(value)~='number' then return 'Unavailable' end;return (value<0 and '|cffff6666-' or '|cff71e4a2+')..money(math.abs(value))..'|r' end
  local qty=details.estimate.quantity;local scan=details.scanPrice;local est=details.estimate
  local vendorLow,vendorUnit,vendorProfit=profitForCost(est.vendor,qty,scan)
  local craftLow,craftUnit,craftProfit=profitForCost(est.craft,qty,scan)
  local gap=details.sales and details.listed and details.sales-details.listed
  local gapText='Unavailable'
  if gap then
    local color=gap>0 and '|cff71e4a2' or gap<0 and '|cffff6666' or '|cffdddddd'
    gapText=color..(string.format('%+.1f',gap):gsub('%.0$',''))..'|r'
  end
  local marketRows={
    {'AH low / unit',scan and money(scan) or 'No scan'},
    {'Stack / listing ('..qty..(details.quantityKnown and ')' or ' assumed)'),scan and money(scan*qty) or 'Unavailable'},
    {'After 5% AH cut',scan and money(math.floor(scan*qty*.95)) or 'Unavailable'},
    {'Listed (last scan)',details.listed and tostring(details.listed) or 'Unavailable'},
    {'Est. sales / day (AHledger)',details.sales and tostring(details.sales) or 'Unavailable'},
    {'Demand gap',gapText},
  }
  local net=scan and math.floor(scan*qty*.95)
  local vendorRows={
    {'AH low / unit',scan and money(scan) or 'No scan'},
    {'Sale after 5% AH cut',net and money(net) or 'Unavailable'},
    {'Vendor cost ('..qty..')',est.vendor~=nil and money(est.vendor)..' ('..(est.vendorLabel=='Vendor reference' and 'ref' or 'observed')..')' or 'Unavailable'},
    {'Profit after AH cut',signed(vendorLow)},
    {'First profitable / unit',vendorUnit and money(vendorUnit) or 'Unavailable'},
    {'P/L at that unit price',signed(vendorProfit)},
  }
  local craftRows={
    {'AH low / unit',scan and money(scan) or 'No scan'},
    {'Sale after 5% AH cut',net and money(net) or 'Unavailable'},
    {'Recipe',est.craftLabel or 'Unavailable'},
    {'Craft cost ('..qty..')',est.craft~=nil and money(est.craft) or 'Unavailable'},
    {'Profit after AH cut',signed(craftLow)},
    {'First profitable / unit',craftUnit and money(craftUnit) or 'Unavailable'},
    {'P/L at that unit price',signed(craftProfit)},
  }
  local historyRows={}
  local periods={{"24 hours",trend and trend.p24},{"48 hours",trend and trend.p48},{"14 days",trend and trend.p14}}
  for i,period in ipairs(periods) do
    local price=period[2];local value=price and money(price) or (trend and "Building history" or "Unavailable")
    if price and type(current)=="number" and current>0 then
      local change=(current/price-1)*100
      local color=change>0 and "|cff46e06f" or change<0 and "|cffff5555" or "|cffdddddd"
      value=value.."  "..color..string.format("(%+.1f%%)",change).."|r"
    end
    historyRows[#historyRows+1]={period[1],value}
  end
  local sections={{'LAST AH SCAN'..(details.scanAge and ('  |  '..details.scanAge..' mins ago') or ''),marketRows}}
  if est.vendor~=nil then sections[#sections+1]={'VENDOR FLIP ON AH',vendorRows,vendorLow or false} end
  if est.craft~=nil then sections[#sections+1]={'CRAFT AND SELL ON AH',craftRows,craftLow or false} end
  sections[#sections+1]={'PRICE HISTORY  |  AHledger',historyRows}
  local y,rowIndex=-12,0
  for i,section in ipairs(sections) do
    local heading=p.headings[i];heading:ClearAllPoints();heading:SetPoint('TOPLEFT',p,'TOPLEFT',12,y);heading:SetText(section[1]);heading:Show();y=y-16
    local badge=p.badges[i];local status=section[3]
    if status~=nil then
      badge:ClearAllPoints();badge:SetPoint('TOPRIGHT',p,'TOPRIGHT',-12,y+18)
      if status==false then
        badge:SetBackdropColor(.12,.12,.12,.95);badge:SetBackdropBorderColor(.45,.45,.45,1);badge.label:SetText('|cffbdbdbdNO SCAN|r')
      elseif status>0 then
        badge:SetBackdropColor(.04,.18,.11,.95);badge:SetBackdropBorderColor(.28,.75,.46,1);badge.label:SetText('|cff71e4a2PROFITABLE|r')
      elseif status<0 then
        badge:SetBackdropColor(.20,.06,.06,.95);badge:SetBackdropBorderColor(.82,.28,.28,1);badge.label:SetText('|cffff7777LOSS|r')
      else
        badge:SetBackdropColor(.12,.12,.12,.95);badge:SetBackdropBorderColor(.45,.45,.45,1);badge.label:SetText('|cffbdbdbdBREAK EVEN|r')
      end
      badge:Show()
    else badge:Hide() end
    for _,row in ipairs(section[2]) do
      rowIndex=rowIndex+1;local line=p.rows[rowIndex]
      line.left:ClearAllPoints();line.left:SetPoint('TOPLEFT',p,'TOPLEFT',12,y);line.left:SetText(row[1]);line.left:Show()
      line.right:ClearAllPoints();line.right:SetPoint('TOPRIGHT',p,'TOPRIGHT',-12,y);line.right:SetText(row[2]);line.right:Show();y=y-17
    end
    y=y-5
  end
  for i=#sections+1,#p.headings do p.headings[i]:Hide();p.badges[i]:Hide() end
  for i=rowIndex+1,#p.rows do p.rows[i].left:Hide();p.rows[i].right:Hide() end
  p:SetHeight(-y+22);placeTrendPanel(p,owner)
  p:Show()
  showRecipePanel(p,id)
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
  local sell=vendorSellValue(id,link)
  pair("Vendor sell / unit",sell and money(sell) or "Loading...")
  if isMerchant and type(cost)=="number" and cost>0 and count and count>0 then
    pair("Vendor buy / unit / stack ("..count..")",money(cost/count).." / "..money(cost))
  else
    local buy=vendorBuyReference(id)
    if buy and count then pair("Vendor buy / unit / stack ("..count..", ref)",money(buy).." / "..money(buy*count))
    else pair("Vendor buy / unit (ref)",buy and money(buy) or "--") end
  end
  if row and type(row.price)=="number" and row.price>0 then
    local observed=type(row.observed)=="number" and math.max(0,math.floor((now-row.observed)/60)) or scanAge
    currentPrice,currentAge,currentSource=row.price,observed,"Last AH scan"
  else
    local reference=MarketeerForeverAPI and MarketeerForeverAPI.GetPrice(id)
    if reference and type(reference.minBuyout)=="number" and reference.minBuyout>0 then
      local minutes=type(reference.updated)=="number" and math.max(0,math.floor((now-reference.updated)/60))
      currentPrice,currentAge,currentSource=reference.minBuyout,minutes,"AH reference"
    end
  end
  if currentPrice then
    local source=currentSource=='AH reference' and ' (ref)' or ''
    pair('AH / unit'..source,currentPrice and money(currentPrice) or '--')
    if count and count>0 then pair('AH stack price ('..count..')'..source,money(currentPrice*count)) end
  end
  if scanAge then tooltip:AddLine("Scan: "..scanAge.."m ago",.7,.8,.75) end
  if not IsShiftKeyDown or not IsShiftKeyDown() then if tooltip==GameTooltip then hideTrendPanel() end;tooltip:Show();return end
  local trend=MarketeerForeverAPI and MarketeerForeverAPI.GetTrend and MarketeerForeverAPI.GetTrend(id)
  local activity=MarketeerForeverAPI and MarketeerForeverAPI.GetPrice(id)
  local scanPrice=row and not row.carried and type(row.price)=='number' and row.price>0 and row.price or nil
  local estimate=profitEstimate(id,count,isMerchant and cost or nil,book,scanPrice)
  local details={estimate=estimate,quantityKnown=count~=nil,scanPrice=scanPrice,scanAge=scanPrice and currentAge or scanAge,listed=row and not row.carried and type(row.quantity)=='number' and row.quantity or nil,sales=activity and type(activity.soldPerDay)=='number' and activity.soldPerDay or nil}
  tooltip:Show()
  if tooltip==GameTooltip then showTrendPanel(tooltip,id,trend,currentPrice,currentAge,currentSource,now,details) end
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
