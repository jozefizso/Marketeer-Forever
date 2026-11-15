local core=MarketeerForeverCore
local panel,search,status,detailTitle,detailInfo
local choices,rows={},{}
local matches,selected,itemOffset,dropOffset={},nil,0,0
local ITEM_PAGE,DROP_PAGE,MAX_DROPS=4,4,14
local function text(parent,x,y,width,font)
  local f=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall');f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);f:SetWidth(width);f:SetJustifyH('LEFT');f:SetWordWrap(false);return f
end
local function button(parent,title,x,y,width,action)
  local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetSize(width,23);b:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);b:SetText(title);b:SetScript('OnClick',action);return b
end
local function renderDrops()
  local item=selected and MarketeerForeverFarmLookup.items[selected]
  for _,row in ipairs(rows) do row:Hide() end
  if not item then detailTitle:SetText('Select an item to see its recorded sources');detailInfo:SetText('');return end
  local total=#item.drops+#(item.sources or {})
  if total==0 then detailTitle:SetText(item.name..'  |  No captured sources');detailInfo:SetText('');return end
  dropOffset=math.max(0,math.min(dropOffset,math.max(0,total-DROP_PAGE)))
  detailTitle:SetText(item.name..'  |  #'..selected)
  detailInfo:SetText((dropOffset+1)..'-'..math.min(dropOffset+DROP_PAGE,total)..' of '..total)
  for i,row in ipairs(rows) do
    local index=dropOffset+i;local d=i<=DROP_PAGE and item.drops[index] or nil;local other=i<=DROP_PAGE and index>#item.drops and (item.sources or {})[index-#item.drops] or nil
    if d then
      local npc=MarketeerForeverFarmLookup.npcs[d[1]] or {'Unknown','Unknown','Unknown'}
      row.npcID=d[1];row.recipeItem=nil;row.name:SetText(npc[1]);row.level:SetText(npc[2]);row.zone:SetText(npc[3]);row.rate:SetText(d[2] and string.format('%.2f%%',d[2]) or '--');row.sample:SetText(d[3] and tostring(d[3]) or '--');row.source:SetText(d[4] and 'Classic *' or 'Forever');row.view:SetText('Loot');row.view:SetEnabled(true);row:Show()
    elseif other then
      row.npcID=nil;row.recipeItem=other[6]=='Created by' and core.HasItemRecipe and core.HasItemRecipe(selected) and selected or nil;row.name:SetText(other[1]);row.level:SetText(other[2]);row.zone:SetText(other[3]);row.rate:SetText(other[4] and string.format('%.2f%%',other[4]) or '--');row.sample:SetText(other[5] or '--');row.source:SetText(other[6]);row.view:SetText(row.recipeItem and 'Recipe' or 'Loot');row.view:SetEnabled(row.recipeItem~=nil);row:Show()
    else row:Hide() end
  end
end
local function renderItems()
  itemOffset=math.max(0,math.min(itemOffset,math.max(0,#matches-ITEM_PAGE)))
  for i,row in ipairs(choices) do
    local id=matches[itemOffset+i];row.itemID=id
    if id then local item=MarketeerForeverFarmLookup.items[id];row.title:SetText(item.name..'  |  #'..id);row.count:SetText((#item.drops+#(item.sources or {}))..' sources');row.recipe:SetShown(core.HasItemRecipe and core.HasItemRecipe(id) or false);row:Show() else row:Hide() end
  end
  status:SetText(#matches==0 and 'Search by item name or ID. Only captured sources are available.' or ((itemOffset+1)..'-'..math.min(itemOffset+ITEM_PAGE,#matches)..' of '..#matches..' items; select one below.'))
  renderDrops()
end
local function find()
  local raw=search:GetText():lower():match('^%s*(.-)%s*$');local id=tonumber(raw:match('item:(%d+)') or raw)
  matches={};selected=nil;itemOffset=0;dropOffset=0
  if raw~='' then for itemId,item in pairs(MarketeerForeverFarmLookup.items) do
    if (id and itemId==id) or (not id and item.name:lower():find(raw,1,true)) then matches[#matches+1]=itemId end
  end end
  table.sort(matches,function(a,b)local x,y=MarketeerForeverFarmLookup.items[a].name,MarketeerForeverFarmLookup.items[b].name;if x==y then return a<b end;return x<y end)
  if #matches==1 then selected=matches[1] end
  renderItems()
  if raw~='' and #matches==0 then status:SetText('This item is not in the saved source snapshot.') end
end
function core.CreateFarmLookupPanel(parent)
  if panel then return panel end
  panel=CreateFrame('Frame',nil,parent);panel:SetAllPoints();panel:Hide()
  text(panel,18,-73,550,'GameFontNormalLarge'):SetText('FIND SOURCES  |  ITEM LOOKUP')
  text(panel,18,-108,55):SetText('Item')
  search=CreateFrame('EditBox',nil,panel,'InputBoxTemplate');search:SetSize(210,24);search:SetPoint('TOPLEFT',panel,'TOPLEFT',62,-102);search:SetAutoFocus(false);search:SetMaxLetters(100)
  button(panel,'Search',288,-102,85,function()search:ClearFocus();find()end)
  search:SetScript('OnEnterPressed',function(s)s:ClearFocus();find()end);search:SetScript('OnEscapePressed',function(s)s:ClearFocus()end)
  status=text(panel,18,-134,590)
  for i=1,ITEM_PAGE do
    local row=CreateFrame('Button',nil,panel,'BackdropTemplate');row:SetPoint('TOPLEFT',panel,'TOPLEFT',14,-154-(i-1)*22);row:SetSize(590,21);row:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8'});row:SetBackdropColor(i%2==0 and .12 or .08,.12,.12,.95)
    row.title=text(row,4,-4,420);row.count=text(row,430,-4,145)
    row.recipe=button(row,'Recipe',0,0,60,function()if row.itemID and core.ShowItemRecipes then core.ShowItemRecipes(row.itemID) end end);row.recipe:ClearAllPoints();row.recipe:SetPoint('RIGHT',row,'RIGHT',-2,0);row.recipe:SetSize(58,20)
    row:SetScript('OnClick',function(s)if s.itemID then selected=s.itemID;dropOffset=0;renderDrops()end end);choices[i]=row
  end
  button(panel,'Previous items',18,-247,105,function()itemOffset=itemOffset-ITEM_PAGE;renderItems()end)
  button(panel,'Next items',130,-247,85,function()itemOffset=itemOffset+ITEM_PAGE;renderItems()end)
  detailTitle=text(panel,18,-281,470,'GameFontNormal');detailInfo=text(panel,500,-282,105)
  local heads={};for i,name in ipairs({'SOURCE NAME','LEVEL','LOCATION','CHANCE','SAMPLES','TYPE'}) do heads[i]=text(panel,18,-302,80,'GameFontNormalSmall');heads[i]:SetText(name) end
  for i=1,MAX_DROPS do
    local row=CreateFrame('Frame',nil,panel,'BackdropTemplate');row:SetPoint('TOPLEFT',panel,'TOPLEFT',14,-320-(i-1)*22);row:SetSize(590,21);row:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8'});row:SetBackdropColor(i%2==0 and .12 or .08,.12,.12,.95)
    row.name=text(row,4,-4,175);row.level=text(row,180,-4,55);row.zone=text(row,240,-4,150);row.rate=text(row,395,-4,60);row.sample=text(row,460,-4,55);row.source=text(row,520,-4,65)
    row.view=button(row,'Loot',0,0,55,function()if row.recipeItem and core.ShowItemRecipes then core.ShowItemRecipes(row.recipeItem) elseif row.npcID and core.ShowFarmMonster then core.ShowFarmMonster(row.npcID) end end);row.view:ClearAllPoints();row.view:SetPoint('RIGHT',row,'RIGHT',-2,0);row.view:SetSize(52,20);rows[i]=row
  end
  local prev=button(panel,'Previous drops',18,-474,110,function()dropOffset=dropOffset-DROP_PAGE;renderDrops()end)
  local next=button(panel,'Next drops',136,-474,90,function()dropOffset=dropOffset+DROP_PAGE;renderDrops()end)
  prev:ClearAllPoints();prev:SetPoint('BOTTOMLEFT',panel,'BOTTOMLEFT',18,22);next:ClearAllPoints();next:SetPoint('BOTTOMLEFT',panel,'BOTTOMLEFT',136,22)
  local note=text(panel,240,-479,370);note:SetText('* Classic Era fallback. Snapshot may be incomplete.');note:ClearAllPoints();note:SetPoint('BOTTOMLEFT',panel,'BOTTOMLEFT',240,27)
  local function layout()
    local width=math.max(590,(panel:GetWidth() or 620)-42);DROP_PAGE=math.max(4,math.min(MAX_DROPS,math.floor(((panel:GetHeight() or 520)-360)/22)))
    local dataWidth=width-58
    local fractions={0,.30,.40,.66,.77,.88,1};local keys={'name','level','zone','rate','sample','source'}
    for i,h in ipairs(heads) do h:ClearAllPoints();h:SetPoint('TOPLEFT',panel,'TOPLEFT',18+dataWidth*fractions[i],-302);h:SetWidth(dataWidth*(fractions[i+1]-fractions[i])-5) end
    for _,row in ipairs(rows) do row:SetWidth(width);for i,k in ipairs(keys) do local field=row[k];field:ClearAllPoints();field:SetPoint('TOPLEFT',row,'TOPLEFT',4+dataWidth*fractions[i],-4);field:SetWidth(dataWidth*(fractions[i+1]-fractions[i])-5) end end
    for _,row in ipairs(choices) do row:SetWidth(width);row.title:SetWidth(width-220);row.count:ClearAllPoints();row.count:SetPoint('TOPLEFT',row,'TOPLEFT',width-210,-4);row.count:SetWidth(135) end
    if selected then renderDrops() end
  end
  panel:SetScript('OnSizeChanged',layout);layout();renderItems()
  function panel:SetItem(id)
    local item=MarketeerForeverFarmLookup.items[tonumber(id)]
    local name=item and item.name or (GetItemInfo and GetItemInfo(id))
    search:SetText(name or ('Item #'..tostring(id)))
    if item then matches={tonumber(id)};selected=tonumber(id);itemOffset=0;dropOffset=0;renderItems()
    else matches={};selected=nil;itemOffset=0;dropOffset=0;renderItems();status:SetText('This item is not in the saved source snapshot.') end
  end
  return panel
end
