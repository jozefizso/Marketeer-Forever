-- A session shopping list: craft counts mean crafts, independent of output yield.
local core=MarketeerForeverCore
local recipes,vendors={},{}
local frame,content,scroll
local render,rendering
local importDialog
local opening,pendingQuantity
local requestedNames={}
local function bagCounts()
  if not C_Container or type(C_Container.GetContainerNumSlots)~='function' or type(C_Container.GetContainerItemInfo)~='function' then return nil end
  local counts,bagIDs,seen={},{},{}
  for bag=0,(NUM_BAG_SLOTS or 4) do bagIDs[#bagIDs+1]=bag;seen[bag]=true end
  local reagent=Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
  if type(reagent)=='number' and reagent>=0 and not seen[reagent] then bagIDs[#bagIDs+1]=reagent end
  for _,bag in ipairs(bagIDs) do
    local ok,slots=pcall(C_Container.GetContainerNumSlots,bag)
    if not ok or (issecretvalue and issecretvalue(slots)) or type(slots)~='number' then return nil end
    for slot=1,slots do
      local success,info=pcall(C_Container.GetContainerItemInfo,bag,slot)
      if not success then return nil end
      if info then
        local id,quantity=info.itemID,info.stackCount
        if issecretvalue and (issecretvalue(id) or issecretvalue(quantity)) then return nil end
        if type(id)~='number' or type(quantity)~='number' then return nil end
        counts[id]=(counts[id] or 0)+quantity
      end
    end
  end
  return counts
end
local function auctionOpen()
  return core.active and AuctionHouseFrame and AuctionHouseFrame.IsShown and AuctionHouseFrame:IsShown()
end
local function openMaterial(id,needed)
  if type(id)~='number' or id<=0 or type(needed)~='number' or needed<=0 then return end
  if not auctionOpen() then print('Marketeer: open the auction house first.');return end
  if opening then print('Marketeer: the previous material is still loading.');return end
  if core.phase~='idle' or (core.IsCompetitionSearchActive and core.IsCompetitionSearchActive()) then print('Marketeer: wait for the auction scan to finish, then try again.');return end
  if not C_AuctionHouse or not C_AuctionHouse.MakeItemKey or not core.CheckBuyout then print('Marketeer: auction search is unavailable.');return end
  local key=C_AuctionHouse.MakeItemKey(id);if not key then print('Marketeer: item details are unavailable.');return end
  opening={id=id};local request=opening
  local ok,err=core.CheckBuyout(key,function(result,message)
    if opening~=request then return end;opening=nil
    if not auctionOpen() then return end
    if not result or not result.tiers or not result.tiers[1] then print('Marketeer: '..(message or 'No listings found.'));return end
    local infoOK,info=pcall(C_AuctionHouse.GetItemKeyInfo,key)
    if not infoOK or not info or type(info.isCommodity)~='boolean' or not AuctionHouseFrame.SelectBrowseResult then print('Marketeer: auction item details are unavailable.');return end
    if MarketeerForeverTabs and MarketeerForeverTabs.HideAll then MarketeerForeverTabs:HideAll() end
    local opened,why=pcall(AuctionHouseFrame.SelectBrowseResult,AuctionHouseFrame,{itemKey=key,minPrice=result.tiers[1].price})
    if not opened then print('Marketeer: could not open this item: '..tostring(why));return end
    if info.isCommodity then
      pendingQuantity={id=id,quantity=needed,delay=.25,elapsed=0}
      if AuctionHouseFrame.QueryItem and AuctionHouseSearchContext and AuctionHouseSearchContext.BuyCommodities then
        local sent=pcall(AuctionHouseFrame.QueryItem,AuctionHouseFrame,AuctionHouseSearchContext.BuyCommodities,key)
        if not sent then pendingQuantity=nil;print('Marketeer: enter the quantity manually; live results could not be requested.') end
      else pendingQuantity=nil;print('Marketeer: enter the quantity manually in the buy window.') end
    else print('Marketeer: this item uses individual auctions; select listings to buy '..needed..' needed.') end
  end)
  if not ok then opening=nil;print('Marketeer: '..tostring(err or 'Could not search auctions.')) elseif opening==request then print('Marketeer: checking live auction listings...') end
end
core.OpenShoppingMaterial=openMaterial
local function applyQuantity()
  local request=pendingQuantity;if not request or not auctionOpen() then return end
  local buy=AuctionHouseFrame.CommoditiesBuyFrame
  local display=buy and buy.BuyDisplay
  if not buy or not buy.IsShown or not buy:IsShown() or not display or not display.GetItemID then return end
  if display:GetItemID()~=request.id then pendingQuantity=nil;return end
  local input=display.QuantityInput;local box=input and (input.InputBox or input.EditBox or input)
  if box and box.HasFocus and box:HasFocus() then pendingQuantity=nil;return end
  if not display.resultsLoaded then return end
  if C_AuctionHouse.HasFullCommoditySearchResults and not C_AuctionHouse.HasFullCommoditySearchResults(request.id) then return end
  if type(display.SetQuantitySelected)~='function' then pendingQuantity=nil;print('Marketeer: enter the quantity manually in the buy window.');return end
  pendingQuantity=nil
  local ok=pcall(display.SetQuantitySelected,display,request.quantity)
  if not ok then print('Marketeer: enter the quantity manually in the buy window.') end
end
local function itemName(id,fallback)
  local name=GetItemInfo and GetItemInfo(id)
  if not name and C_Item and C_Item.GetItemNameByID then name=C_Item.GetItemNameByID(id) end
  local known=MarketeerForeverFarmLookup and MarketeerForeverFarmLookup.items[id]
  name=name or (known and known.name) or (MarketeerForeverFarmData and MarketeerForeverFarmData.items and MarketeerForeverFarmData.items[id])
  if not name and not requestedNames[id] and C_Item and C_Item.RequestLoadItemDataByID then requestedNames[id]=true;pcall(C_Item.RequestLoadItemDataByID,id) end
  return name or fallback or ('Item #'..id)
end
-- Only prices observed in the latest completed scan for this market are used.
local function scanPrice(id)
  if not id or not core.Market then return nil end
  local market=core.Market();local db=MarketeerForeverCoreDB
  local book=market and db and db.prices and db.prices[market]
  local row=book and book.items and book.items[id]
  if type(row)=='table' and not row.carried and type(row.price)=='number' and row.price>0 then return row.price end
end
local function priceText(value)
  if not value then return '--' end
  value=math.floor(value*100+.5)/100
  local gold=math.floor(value/10000);local silver=math.floor((value-gold*10000)/100);local copper=value-gold*10000-silver*100
  local parts={};if gold>0 then parts[#parts+1]=gold..'g' end;if silver>0 then parts[#parts+1]=silver..'s' end
  if copper>0 or #parts==0 then parts[#parts+1]=string.format('%.2f',copper):gsub('0+$',''):gsub('%.$','')..'c' end
  return table.concat(parts,' ')
end
local function label(parent,x,y,w,font)
  local t
  if parent.pooled then parent.labelIndex=(parent.labelIndex or 0)+1;parent.labels=parent.labels or {};t=parent.labels[parent.labelIndex];if not t then t=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall');parent.labels[parent.labelIndex]=t end;t:SetFontObject(font or 'GameFontHighlightSmall');t:ClearAllPoints();t:Show()
  else t=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall') end
  t:SetPoint('TOPLEFT',x,y);t:SetWidth(w);t:SetJustifyH('LEFT');t:SetWordWrap(false);return t
end
local function button(parent,text,w,fn)
  local b
  if parent.pooled then parent.buttonIndex=(parent.buttonIndex or 0)+1;parent.buttons=parent.buttons or {};b=parent.buttons[parent.buttonIndex];if not b then b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');parent.buttons[parent.buttonIndex]=b end;b:ClearAllPoints();b:Show()
  else b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate') end
  b:SetSize(w,22);b:SetText(text);b:SetScript('OnClick',fn);return b
end
local function create()
  if frame then return end
  frame=CreateFrame('Frame','MarketeerShoppingList',UIParent,'BackdropTemplate');frame:SetSize(560,420);frame:SetPoint('CENTER',UIParent,'CENTER',260,0);frame:SetFrameStrata('DIALOG');frame:SetMovable(true);frame:SetResizable(true);frame:SetClampedToScreen(true);frame:EnableMouse(true)
  if frame.SetResizeBounds then frame:SetResizeBounds(500,260,800,900) elseif frame.SetMinResize then frame:SetMinResize(500,260) end
  frame:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1});frame:SetBackdropColor(.055,.075,.065,.98);frame:SetBackdropBorderColor(.25,.48,.34,1)
  local bar=CreateFrame('Frame',nil,frame);bar:SetPoint('TOPLEFT');bar:SetPoint('TOPRIGHT');bar:SetHeight(38);bar:EnableMouse(true);bar:RegisterForDrag('LeftButton');bar:SetScript('OnDragStart',function()frame:StartMoving()end);bar:SetScript('OnDragStop',function()frame:StopMovingOrSizing()end)
  label(bar,14,-12,280,'GameFontNormal'):SetText('SHOPPING LIST')
  local close=button(bar,'X',28,function()frame:Hide()end);close:SetPoint('TOPRIGHT',-8,-8)
  scroll=CreateFrame('ScrollFrame',nil,frame,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',12,-42);scroll:SetPoint('BOTTOMRIGHT',-30,42)
  content=CreateFrame('Frame',nil,scroll);content:SetSize(360,1);scroll:SetScrollChild(content)
  local clear=button(frame,'Clear list',85,function()recipes={};vendors={};render()end);clear:SetPoint('BOTTOMLEFT',12,10)
  local import=button(frame,'Import',85,function()importDialog:Show() end);import:SetPoint('BOTTOMLEFT',105,10)
  import:SetScript('OnEnter',function(self)
    if GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_TOP');GameTooltip:SetText('Import shopping list');GameTooltip:AddLine('Paste a Wowhead or Auctionator shopping-list export to add its items and quantities.',1,1,1,true);GameTooltip:Show() end
  end)
  import:SetScript('OnLeave',function()if GameTooltip then GameTooltip:Hide() end end)
  local resize=button(frame,'Resize',64,function()end);resize:SetPoint('BOTTOMRIGHT',-8,8)
  resize:SetScript('OnMouseDown',function(_,which)if which=='LeftButton' then frame:StartSizing('BOTTOMRIGHT') end end);resize:SetScript('OnMouseUp',function()frame:StopMovingOrSizing()end);resize:SetScript('OnHide',function()frame:StopMovingOrSizing()end)
  importDialog=CreateFrame('Frame',nil,frame,'BackdropTemplate');importDialog:SetSize(340,250);importDialog:SetPoint('CENTER');importDialog:SetFrameLevel(frame:GetFrameLevel()+20);importDialog:EnableMouse(true)
  importDialog:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1});importDialog:SetBackdropColor(.055,.075,.065,1);importDialog:SetBackdropBorderColor(.25,.48,.34,1)
  label(importDialog,12,-12,310,'GameFontNormal'):SetText('IMPORT SHOPPING LIST')
  label(importDialog,12,-34,310):SetText('Paste a Wowhead / Auctionator export below.')
  local pasteBox=CreateFrame('Frame',nil,importDialog,'BackdropTemplate');pasteBox:SetPoint('TOPLEFT',10,-53);pasteBox:SetPoint('BOTTOMRIGHT',-29,61)
  pasteBox:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1});pasteBox:SetBackdropColor(.16,.18,.17,1);pasteBox:SetBackdropBorderColor(.45,.50,.47,1);pasteBox:EnableMouse(true)
  local pasteScroll=CreateFrame('ScrollFrame',nil,importDialog,'UIPanelScrollFrameTemplate');pasteScroll:SetPoint('TOPLEFT',15,-58);pasteScroll:SetPoint('BOTTOMRIGHT',-34,65)
  local paste=CreateFrame('EditBox',nil,pasteScroll);paste:SetMultiLine(true);paste:SetAutoFocus(false);paste:SetFontObject('ChatFontNormal');paste:SetWidth(285);paste:SetHeight(130);paste:SetMaxLetters(0);pasteScroll:SetScrollChild(paste)
  pasteBox:SetScript('OnMouseDown',function()paste:SetFocus()end)
  importDialog:SetScript('OnShow',function()paste:SetFocus()end)
  paste:SetScript('OnEscapePressed',function()importDialog:Hide()end)
  local message=label(importDialog,12,-192,315);message:SetText('')
  local accept=button(importDialog,'Import',85,function()
    local ok,description=core.ImportShoppingList(paste:GetText())
    if ok then paste:SetText('');importDialog:Hide();print('Marketeer: '..description) else message:SetText(description) end
  end);accept:SetPoint('BOTTOMLEFT',12,10)
  local cancel=button(importDialog,'Cancel',85,function()importDialog:Hide()end);cancel:SetPoint('BOTTOMRIGHT',-12,10)
  importDialog:Hide()
  frame:SetScript('OnSizeChanged',function()if render then render() end end)
  frame:Hide()
end
local widgets,used={},0
local function line(kind,y,width)
  used=used+1;local row=widgets[used];if not row then row=CreateFrame('Frame',nil,content);row.pooled=true;widgets[used]=row end
  row.labelIndex=0;row.buttonIndex=0;row:ClearAllPoints();row:SetPoint('TOPLEFT',0,-y);row:SetSize(width,24);row:Show();return row
end
render=function()
  if not content or rendering then return end
  rendering=true
  for _,row in ipairs(widgets) do row:Hide();for _,v in ipairs(row.labels or {}) do v:Hide() end;for _,v in ipairs(row.buttons or {}) do v:Hide() end;if row.edit then row.edit:Hide() end end;used=0
  local width=math.max(452,(frame:GetWidth() or 560)-48);content:SetWidth(width);local y=0
  local columns={name={x=8,width=width-290},price={x=width-278,width=80},progress={x=width-195,width=105}}
  local materials={};local carried=bagCounts()
  if #recipes>0 then local r=line('heading',y,width);label(r,2,-4,width,'GameFontNormalSmall'):SetText('RECIPES  |  CRAFTS');y=y+25 end
  for i,recipe in ipairs(recipes) do
    local row=line('recipe',y,width);label(row,2,-4,width-150):SetText(recipe.name)
    local remove=button(row,'X',24,function()table.remove(recipes,i);render()end);remove:SetPoint('TOPRIGHT',0,0)
    local plus=button(row,'+',24,function()recipe.count=math.min(10000,recipe.count+1);render()end);plus:SetPoint('RIGHT',remove,'LEFT',-3,0)
    local edit=row.edit;if not edit then edit=CreateFrame('EditBox',nil,row,'InputBoxTemplate');row.edit=edit;edit:SetAutoFocus(false);edit:SetNumeric(true);edit:SetMaxLetters(5) end;edit:ClearAllPoints();edit:SetSize(44,22);edit:SetPoint('RIGHT',plus,'LEFT',-4,0);edit:SetText(tostring(recipe.count));edit:Show()
    edit:SetScript('OnTextChanged',function(s,userInput)if userInput then local n=tonumber(s:GetText());if n and n>0 then recipe.count=math.min(10000,math.floor(n)) end end end)
    edit:SetScript('OnEditFocusGained',function(s)s.startCount=recipe.count end)
    edit:SetScript('OnEditFocusLost',function()if not rendering then render() end end)
    edit:SetScript('OnEnterPressed',function(s)s:ClearFocus();render()end)
    edit:SetScript('OnEscapePressed',function(s)recipe.count=s.startCount or recipe.count;s:ClearFocus();render()end)
    local minus=button(row,'-',24,function()recipe.count=math.max(1,recipe.count-1);render()end);minus:SetPoint('RIGHT',edit,'LEFT',-4,0)
    for _,m in ipairs(recipe.materials) do local key=m.id or ('name:'..m.name:lower());local a=materials[key] or {id=m.id,name=m.name,quantity=0};a.quantity=a.quantity+m.quantity*recipe.count;if recipe.imported then a.imported=true end;materials[key]=a end
    y=y+27
  end
  local all={};for _,m in pairs(materials) do all[#all+1]=m end;table.sort(all,function(a,b)return a.name:lower()<b.name:lower()end)
  if #all>0 then local r=line('heading',y,width);label(r,columns.name.x,-4,columns.name.width,'GameFontNormalSmall'):SetText('MATERIALS NEEDED');local price=label(r,columns.price.x,-4,columns.price.width,'GameFontNormalSmall');price:SetJustifyH('RIGHT');price:SetText('AH / UNIT');local h=label(r,columns.progress.x,-4,columns.progress.width,'GameFontNormalSmall');h:SetJustifyH('RIGHT');h:SetText('IN BAGS / NEED');y=y+24 end
  for _,m in ipairs(all) do
    local r=line('material',y,width);label(r,columns.name.x,-4,columns.name.width):SetText(m.id and itemName(m.id,m.name) or (m.name..' (unresolved)'))
    local unit=label(r,columns.price.x,-4,columns.price.width);unit:SetJustifyH('RIGHT');unit:SetText(priceText(scanPrice(m.id)))
    local have=m.id and carried and (carried[m.id] or 0);local progress=label(r,columns.progress.x,-4,columns.progress.width);progress:SetJustifyH('RIGHT')
    if have and have>=m.quantity then progress:SetText('|cff73e6a3[OK] '..have..' / '..m.quantity..'|r') else progress:SetText((have and tostring(have) or '--')..' / '..m.quantity) end
    if m.id and auctionOpen() then local buy=button(r,'Open',50,function()local counts=bagCounts();if not counts then print('Marketeer: bag quantities are unavailable; try again.');return end;local missing=math.max(0,m.quantity-(counts[m.id] or 0));if missing>0 then openMaterial(m.id,missing) else print('Marketeer: you already have the required amount in your bags.') end end);buy:SetPoint('TOPRIGHT',-28,0);buy:SetEnabled(have~=nil and have<m.quantity) end
    if m.imported then
      local remove=button(r,'X',24,function()
        local key=m.id or ('name:'..m.name:lower())
        for i=#recipes,1,-1 do
          local recipe=recipes[i]
          if recipe.imported then
            for j=#recipe.materials,1,-1 do local item=recipe.materials[j];if (item.id or ('name:'..item.name:lower()))==key then table.remove(recipe.materials,j) end end
            if #recipe.materials==0 then table.remove(recipes,i) end
          end
        end
        render()
      end);remove:SetPoint('TOPRIGHT',0,0)
    end
    y=y+22
  end
  if #vendors>0 then local r=line('heading',y,width);label(r,columns.name.x,-4,columns.name.width,'GameFontNormalSmall'):SetText('VENDOR ITEMS');local price=label(r,columns.price.x,-4,columns.price.width,'GameFontNormalSmall');price:SetJustifyH('RIGHT');price:SetText('AH / UNIT');y=y+24 end
  for i,item in ipairs(vendors) do local r=line('vendor',y,width);label(r,columns.name.x,-4,columns.name.width):SetText(item.name);local unit=label(r,columns.price.x,-4,columns.price.width);unit:SetJustifyH('RIGHT');unit:SetText(priceText(scanPrice(item.id)));local have=carried and (carried[item.id] or 0);local state=label(r,columns.progress.x,-4,columns.progress.width);state:SetJustifyH('RIGHT');state:SetText(have==nil and '--' or have>0 and '|cff73e6a3[OK]|r' or 'Needed');local remove=button(r,'X',24,function()table.remove(vendors,i);render()end);remove:SetPoint('TOPRIGHT',0,0);y=y+25 end
  if #recipes==0 and #vendors==0 then local r=line('empty',y,width);label(r,2,-4,width):SetText('Add a recipe or vendor item to get started.');y=y+25 end
  content:SetHeight(math.max(1,y+5))
  rendering=false
end
local itemEvents=CreateFrame('Frame');for _,event in ipairs({'GET_ITEM_INFO_RECEIVED','BAG_UPDATE_DELAYED','AUCTION_HOUSE_SHOW','AUCTION_HOUSE_CLOSED','COMMODITY_SEARCH_RESULTS_RECEIVED','COMMODITY_SEARCH_RESULTS_UPDATED'}) do pcall(itemEvents.RegisterEvent,itemEvents,event) end;itemEvents:SetScript('OnEvent',function(_,event,id,success)
  if event=='AUCTION_HOUSE_CLOSED' then opening=nil;pendingQuantity=nil end
  if event=='AUCTION_HOUSE_SHOW' or event=='AUCTION_HOUSE_CLOSED' then
    if C_Timer and C_Timer.After then C_Timer.After(0,function()if frame and frame:IsShown() then render() end end) elseif frame and frame:IsShown() then render() end
    return
  end
  if (event=='COMMODITY_SEARCH_RESULTS_RECEIVED' or event=='COMMODITY_SEARCH_RESULTS_UPDATED') then
    -- RECEIVED carries no item ID on Forever; verify the active item in applyQuantity.
    if pendingQuantity and (event=='COMMODITY_SEARCH_RESULTS_RECEIVED' or pendingQuantity.id==id) then pendingQuantity.delay=.25 end
    return
  end
  if event=='GET_ITEM_INFO_RECEIVED' then if not success or not requestedNames[id] then return end;requestedNames[id]=nil end
  if not frame or not frame:IsShown() then return end
  for _,row in ipairs(widgets) do if row.edit and row.edit.HasFocus and row.edit:HasFocus() then return end end
  render()
end)
itemEvents:SetScript('OnUpdate',function(_,delta)
  local request=pendingQuantity;if not request then return end
  request.elapsed=request.elapsed+delta;request.delay=math.max(0,request.delay-delta)
  if request.elapsed>15 then pendingQuantity=nil;print('Marketeer: quantity could not be filled; enter '..request.quantity..' manually.');return end
  if request.delay==0 then applyQuantity() end
end)
if core.Subscribe then core.Subscribe(function(event)if event=='complete' and frame and frame:IsShown() then render() end end) end
-- Wowhead exports a list title followed by caret-separated Auctionator searches.
function core.ImportShoppingList(text)
  if type(text)~='string' or #text>100000 then return false,'Paste a valid export (up to 100 KB).' end
  local parts={};for part in (text..'^'):gmatch('(.-)%^') do parts[#parts+1]=part end
  local title=parts[1] and parts[1]:match('^%s*(.-)%s*$')
  if not title or title=='' or #parts<2 or #parts>501 then return false,'Could not read the list title and items.' end
  local items,wanted={},{}
  for i=2,#parts do
    local fields={};for field in (parts[i]..';'):gmatch('(.-);') do fields[#fields+1]=field end
    local name=fields[1] and fields[1]:match('^%s*"(.-)"%s*$')
    local quantity=fields[14] and tonumber(fields[14])
    if not name or name=='' or #fields~=14 or not quantity or quantity<1 or quantity>1000000 or quantity~=math.floor(quantity) then return false,'Invalid item or quantity at entry '..(i-1)..'.' end
    for j=2,13 do if fields[j]~='' then return false,'Unsupported search filter at entry '..(i-1)..'.' end end
    items[#items+1]={name=name,quantity=quantity};wanted[name:lower()]=true
  end
  local ids={}
  local function remember(id,name)
    if type(id)~='number' or type(name)~='string' then return end
    local key=name:lower();if not wanted[key] then return end
    if ids[key]==nil then ids[key]=id elseif ids[key]~=id then ids[key]=false end
  end
  local catalog=_G.MarketeerForeverItemNames
  if type(catalog)=='table' and type(catalog.items)=='table' then for id,name in pairs(catalog.items) do remember(id,name) end end
  local lookup=_G.MarketeerForeverFarmLookup
  if type(lookup)=='table' and type(lookup.items)=='table' then for id,item in pairs(lookup.items) do if type(item)=='table' then remember(id,item.name) end end end
  local unresolved=0
  for _,item in ipairs(items) do item.id=ids[item.name:lower()] or nil;if not item.id then unresolved=unresolved+1 end end
  recipes[#recipes+1]={name=title,count=1,materials=items,imported=true}
  create();render();frame:Show()
  return true,'Imported '..#items..' items'..(unresolved>0 and ('; '..unresolved..' could not be matched to an item ID.') or '.')
end
function core.OpenShoppingList() create();render();frame:Show() end
SLASH_MARKETEERSHOPPING1='/marketeershopping'
SlashCmdList.MARKETEERSHOPPING=core.OpenShoppingList
function core.AddShoppingRecipe(recipe)
  if type(recipe)~='table' or type(recipe.materials)~='table' then return end
  local key=recipe.id or recipe.output or recipe.name;local found
  for _,r in ipairs(recipes) do if r.key==key then found=r;break end end
  if found then found.count=math.min(10000,found.count+1) else
    local r={key=key,name=recipe.name or 'Recipe',count=1,materials={}}
    for _,m in ipairs(recipe.materials) do if type(m.id)=='number' and type(m.quantity)=='number' and m.quantity>0 then r.materials[#r.materials+1]={id=m.id,name=m.name or ('Item #'..m.id),quantity=m.quantity} end end
    recipes[#recipes+1]=r
  end
  create();render();frame:Show()
end
function core.AddShoppingVendor(item)
  if type(item)~='table' or type(item.id)~='number' then return end
  local found=false;for _,v in ipairs(vendors) do if v.id==item.id then found=true;break end end
  if not found then vendors[#vendors+1]={id=item.id,name=item.name or ('Item #'..item.id)} end
  create();render();frame:Show()
end
