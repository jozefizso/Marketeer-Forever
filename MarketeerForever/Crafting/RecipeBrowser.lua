local core=MarketeerForeverCore
local panel,search,status,title,summary,marketLine,pageText,auctionButton
local recipeRows,materialRows={},{}
local matches,selected,offset={},nil,0
local PAGE=4
local function data() return (MarketeerForeverCraftCraftCatalog and MarketeerForeverCraftCraftCatalog.recipes) or {} end
local function nameFor(id,fallback)
  local saved=MarketeerForeverFarmLookup and MarketeerForeverFarmLookup.items[id]
  local value=GetItemInfo and GetItemInfo(id)
  return (type(value)=='string' and value~='' and value) or (saved and saved.name) or fallback or ('Item #'..id)
end
function core.HasItemRecipe(id)
  for _,r in pairs(data()) do if r.output==id then return true end end
  return false
end
local function money(n)
  if type(n)~='number' then return '--' end
  if n<0 then return '-'..money(-n) end
  n=math.floor(n+.5);local g=math.floor(n/10000);local s=math.floor(n%10000/100);local c=n%100
  if g>0 then return g..'g '..s..'s '..c..'c' elseif s>0 then return s..'s '..c..'c' end;return c..'c'
end
local function price(book,id)
  local row=book and book.items and book.items[id]
  if type(row)=='table' and not row.carried and type(row.price)=='number' and row.price>0 then return row.price,row.quantity end
end
function core.RecipeEstimate(recipe,book,activity)
  local cost=0;local missing=0
  for _,m in ipairs(recipe.materials or {}) do local p=price(book,m.id);if p then cost=cost+p*m.quantity else missing=missing+1 end end
  local sale,listed=price(book,recipe.output)
  local lo,hi=recipe.yieldMin,recipe.yieldMax
  local valid=type(lo)=='number' and type(hi)=='number' and lo>0 and hi>=lo
  local gainMin,gainMax
  if missing==0 and sale and valid then gainMin=sale*lo*.95-cost;gainMax=sale*hi*.95-cost end
  return {cost=missing==0 and cost or nil,missing=missing,sale=sale,listed=listed,sales=activity and activity.soldPerDay or nil,gainMin=gainMin,gainMax=gainMax}
end
local function label(parent,x,y,width,font)
  local f=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall');f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);f:SetWidth(width);f:SetJustifyH('LEFT');f:SetWordWrap(false);return f
end
local function button(parent,name,x,y,w,fn)
  local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);b:SetSize(w,23);b:SetText(name);b:SetScript('OnClick',fn);return b
end
local function auctionAvailable()
  return core.active and AuctionHouseFrame and AuctionHouseFrame:IsShown() and core.OpenItemAuctions~=nil or false
end
local function updateAuctionButton()
  local r=selected and data()[selected]
  local available=auctionAvailable()
  if auctionButton then auctionButton:SetShown(r and r.output and available or false) end
  for _,row in ipairs(materialRows) do if row.auctions then row.auctions:SetShown(row.id and available or false) end end
end
local function renderDetail()
  updateAuctionButton()
  for _,row in ipairs(materialRows) do row:Hide() end
  if not selected then title:SetText('Select a recipe');summary:SetText('');marketLine:SetText('');return end
  local r=data()[selected];if not r then return end
  local market=core.Market();local book=market and MarketeerForeverCoreDB and MarketeerForeverCoreDB.prices and MarketeerForeverCoreDB.prices[market]
  local matching=MarketeerForeverMarketActivityMarket and MarketeerForeverMarketActivityMarket()
  local info=matching and MarketeerForeverAPI.GetTableInfo();local infoMarket=info and type(info.market)=='string' and info.market:lower():gsub('/','.')
  local activity=matching and matching==infoMarket and MarketeerForeverAPI.GetPrice(r.output)
  if activity and (type(activity.market)~='string' or activity.market:lower():gsub('/','.')~=matching) then activity=nil end
  local v=core.RecipeEstimate(r,book,activity)
  title:SetText(r.name..' | '..r.profession..' | Skill '..tostring(r.required or '?')..(r.review and ' | needs review' or ''))
  local yield=type(r.yieldMin)=='number' and type(r.yieldMax)=='number' and r.yieldMin>0 and (r.yieldMin==r.yieldMax and tostring(r.yieldMin) or (r.yieldMin..'-'..r.yieldMax)) or '?'
  local profit=money(v.gainMin);if v.gainMin and v.gainMax~=v.gainMin then profit=profit..' to '..money(v.gainMax) end
  summary:SetText('Cost / craft: '..money(v.cost)..'  |  Yield: '..yield..'  |  Sell / unit: '..money(v.sale)..'  |  Profit / craft: '..profit)
  local age=book and type(book.observed)=='number' and math.max(0,math.floor(((GetServerTime and GetServerTime() or time())-book.observed)/60))
  marketLine:SetText('Sales/day: '..(v.sales~=nil and string.format('%.1f',v.sales) or '--')..'  |  Listed: '..(v.listed~=nil and tostring(v.listed) or '--')..'  |  Scan: '..(age and age..'m ago' or 'unavailable')..(v.missing>0 and ('  |  Missing material prices: '..v.missing) or ''))
  for i,row in ipairs(materialRows) do local m=r.materials and r.materials[i];if m then
    row.id=m.id;local p=price(book,m.id);row.name:SetText(m.quantity..' x '..nameFor(m.id,m.name));row.unit:SetText('Unit: '..money(p));row.total:SetText('Total: '..money(p and p*m.quantity))
    local source=MarketeerForeverFarmLookup and MarketeerForeverFarmLookup.items[m.id];row.sources:SetEnabled(source and (#source.drops+#(source.sources or {}))>0 or false);row.auctions:SetShown(auctionAvailable());row:Show()
  else row.id=nil;row:Hide() end end
end
local function render()
  offset=math.max(0,math.min(offset,math.max(0,#matches-PAGE)))
  for i,row in ipairs(recipeRows) do local id=matches[offset+i];row.id=id;if id then local r=data()[id];row.name:SetText(r.name..' | '..r.profession..' | Skill '..tostring(r.required or '?'));row:Show() else row:Hide() end end
  pageText:SetText(#matches==0 and 'Search for an item or recipe name, or an item ID.' or ((offset+1)..'-'..math.min(offset+PAGE,#matches)..' of '..#matches..' recipes'))
  renderDetail()
end
local function find(id,recipeID)
  local q=search:GetText():lower():match('^%s*(.-)%s*$');local exact=id or tonumber(q:match('item:(%d+)') or q);matches={};selected=nil;offset=0
  if exact or q~='' then for spell,r in pairs(data()) do
    if (exact and r.output==exact) or (not exact and (r.name:lower():find(q,1,true) or nameFor(r.output,''):lower():find(q,1,true))) then matches[#matches+1]=spell end
  end end
  table.sort(matches,function(a,b) local x,y=data()[a].name,data()[b].name;if x==y then return a<b end;return x<y end)
  if #matches>0 then selected=matches[1];if recipeID then for i,spell in ipairs(matches) do if spell==recipeID then selected=spell;offset=math.floor((i-1)/PAGE)*PAGE;break end end end end
  render();if #matches==0 and (exact or q~='') then pageText:SetText('No recipe was found in the saved crafting catalog.') end
end
function core.CreateRecipeBrowser(parent)
  if panel then return panel end
  panel=CreateFrame('Frame',nil,parent);panel:SetAllPoints();panel:Hide()
  label(panel,18,-73,550,'GameFontNormalLarge'):SetText('RECIPES  |  CRAFTING')
  label(panel,18,-108,45):SetText('Item')
  search=CreateFrame('EditBox',nil,panel,'InputBoxTemplate');search:SetSize(210,24);search:SetPoint('TOPLEFT',panel,'TOPLEFT',62,-102);search:SetAutoFocus(false);search:SetMaxLetters(100)
  button(panel,'Search',288,-102,85,function()search:ClearFocus();find()end)
  auctionButton=button(panel,'Open auctions',385,-102,120,function()local r=selected and data()[selected];if r and core.OpenItemAuctions then core.OpenItemAuctions(r.output) end end);auctionButton:Hide()
  search:SetScript('OnEnterPressed',function(s)s:ClearFocus();find()end);search:SetScript('OnEscapePressed',function(s)s:ClearFocus()end)
  pageText=label(panel,18,-135,580)
  for i=1,PAGE do local row=CreateFrame('Button',nil,panel,'BackdropTemplate');row:SetPoint('TOPLEFT',panel,'TOPLEFT',14,-154-(i-1)*22);row:SetSize(590,21);row:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8'});row:SetBackdropColor(i%2==0 and .12 or .08,.12,.12,.95);row.name=label(row,4,-4,570);row:SetScript('OnClick',function(s)if s.id then selected=s.id;renderDetail()end end);recipeRows[i]=row end
  button(panel,'Previous',18,-247,85,function()offset=offset-PAGE;render()end);button(panel,'Next',110,-247,85,function()offset=offset+PAGE;render()end)
  title=label(panel,18,-280,590,'GameFontNormal');summary=label(panel,18,-303,590);marketLine=label(panel,18,-324,590)
  label(panel,18,-345,590,'GameFontNormalSmall'):SetText('MATERIALS  |  LAST SCAN PRICES')
  for i=1,8 do local row=CreateFrame('Frame',nil,panel,'BackdropTemplate');row:SetPoint('TOPLEFT',panel,'TOPLEFT',14,-362-(i-1)*16);row:SetSize(590,16);row:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8'});row:SetBackdropColor(i%2==0 and .12 or .08,.12,.12,.95);row.name=label(row,4,-1,240);row.unit=label(row,245,-1,95);row.total=label(row,345,-1,100);row.sources=button(row,'Sources',0,0,75,function()if row.id then core.ShowItemDrops(row.id)end end);row.sources:ClearAllPoints();row.sources:SetPoint('RIGHT',row,'RIGHT',-3,0);row.sources:SetSize(75,16);row.auctions=button(row,'Auctions',0,0,75,function()if row.id and core.OpenItemAuctions then core.OpenItemAuctions(row.id) end end);row.auctions:ClearAllPoints();row.auctions:SetPoint('RIGHT',row.sources,'LEFT',-4,0);row.auctions:SetSize(75,16);row.auctions:Hide();materialRows[i]=row end
  local note=label(panel,18,-1,590);note:SetText('Profit assumes each item sells at the last scan price; 5% AH cut, no deposits.');note:ClearAllPoints();note:SetPoint('BOTTOMLEFT',panel,'BOTTOMLEFT',18,8)
  local function layout()local width=math.max(590,(panel:GetWidth() or 620)-42);for _,row in ipairs(recipeRows) do row:SetWidth(width);row.name:SetWidth(width-12) end;for _,row in ipairs(materialRows) do row:SetWidth(width);row.name:SetWidth(width-425);row.unit:ClearAllPoints();row.unit:SetPoint('TOPLEFT',row,'TOPLEFT',width-415,-1);row.total:ClearAllPoints();row.total:SetPoint('TOPLEFT',row,'TOPLEFT',width-310,-1) end;title:SetWidth(width);summary:SetWidth(width);marketLine:SetWidth(width) end
  for _,event in ipairs({'AUCTION_HOUSE_SHOW','AUCTION_HOUSE_CLOSED'}) do panel:RegisterEvent(event) end
  panel:SetScript('OnEvent',function()if C_Timer and C_Timer.After then C_Timer.After(0,updateAuctionButton) else updateAuctionButton() end end)
  panel:SetScript('OnSizeChanged',layout);panel:SetScript('OnShow',function()if selected then renderDetail()end end);layout();render()
  function panel:SetItem(id,recipeID) id=tonumber(id);search:SetText(nameFor(id,'Item #'..tostring(id)));find(id,tonumber(recipeID)) end
  return panel
end
