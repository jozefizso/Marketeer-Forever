local core=MarketeerForeverCore
local panel,search,status,detailTitle,detailInfo
local choices,rows={},{}
local matches,selected,itemOffset,dropOffset={},nil,0,0
local ITEM_PAGE,DROP_PAGE,MAX_DROPS=4,4,14
local sortMode,sortItem,sortDistances='alphabetical',nil,nil
local function nearestVendor(itemID)
  local data=MarketeerLocalVendors
  if not (type(data)=='table' and C_Map and CreateVector2D) then return nil,'Local vendor locations are unavailable.' end
  if not (C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition and C_Map.GetWorldPosFromMapPos) then return nil,'Player location is unavailable.' end
  local ids=data.items[itemID];if type(ids)~='table' or #ids==0 then return nil,'No local vendor locations are available for this item.' end
  local map=C_Map.GetBestMapForUnit('player');local pos=map and C_Map.GetPlayerMapPosition(map,'player')
  if not pos then return nil,'Player location is unavailable.' end
  local continent,player=C_Map.GetWorldPosFromMapPos(map,pos);if not player then return nil,'World coordinates are unavailable here.' end
  local px,py=player:GetXY();local faction=UnitFactionGroup and UnitFactionGroup('player');local side=faction=='Alliance' and 'A' or faction=='Horde' and 'H' or nil
  if not side then return nil,'Cannot identify your faction.' end
  local best;local distances,targets={},{}
  for _,id in ipairs(ids) do
    local npc=data.npcs[id];local friendly=npc and npc[2];local spawns=npc and npc[3]
    if (friendly=='AH' or friendly==side) and type(spawns)=='table' then
      for area,points in pairs(spawns) do local uiMap=data.areas[area]
        if type(uiMap)=='number' and uiMap>0 and type(points)=='table' then for _,point in ipairs(points) do
          local x,y=point[1],point[2]
          if type(x)=='number' and type(y)=='number' and x>=0 and x<=100 and y>=0 and y<=100 and point[3]==nil then
            local good,worldID,world=pcall(C_Map.GetWorldPosFromMapPos,uiMap,CreateVector2D(x/100,y/100))
            if good and world and worldID==continent then local wx,wy=world:GetXY();local distance=(wx-px)^2+(wy-py)^2
              local name=npc[1] or 'Vendor';local key=name:lower();local previous=distances[key]
              if not previous or distance<previous then distances[key]=distance end
              local candidate={id=id,map=uiMap,x=x/100,y=y/100,distance=distance,name=name}
              targets[key]=targets[key] or {};targets[key][#targets[key]+1]=candidate
              if not best or distance<best.distance then best=candidate end
            end
          end
        end end
      end
    end
  end
  return best,best and nil or 'No friendly vendor with a usable location on this continent was found.',distances,targets
end
local function canGuide()
  return (TomTom and type(TomTom.AddWaypoint)=='function') or (C_Map and type(C_Map.SetUserWaypoint)=='function' and UiMapPoint and type(UiMapPoint.CreateFromCoordinates)=='function')
end
local function trackVendor(vendor)
  if not vendor then return end
  if TomTom and type(TomTom.AddWaypoint)=='function' then
    local ok,uid=pcall(TomTom.AddWaypoint,TomTom,vendor.map,vendor.x,vendor.y,{title=vendor.name,source='Marketeer',persistent=false,minimap=true,world=true,crazy=true,silent=true})
    if ok and uid then status:SetText('Arrow set to '..vendor.name..'.');return end
  end
  if C_Map and type(C_Map.SetUserWaypoint)=='function' and UiMapPoint and type(UiMapPoint.CreateFromCoordinates)=='function' then
    local ok,point=pcall(UiMapPoint.CreateFromCoordinates,vendor.map,vendor.x,vendor.y)
    if ok and point then local set,result=pcall(C_Map.SetUserWaypoint,point)
      if set and result~=false then
        if C_SuperTrack and type(C_SuperTrack.SetSuperTrackedUserWaypoint)=='function' then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint,true) end
        status:SetText('Waypoint set to '..vendor.name..'.');return
      end
    end
  end
  status:SetText('No supported waypoint arrow is available in this client.')
end
local function guideToVendor()
  if not selected then status:SetText('Select an item first.');return end
  local vendor,err=nearestVendor(selected);if not vendor then status:SetText(err);return end
  trackVendor(vendor)
end
local function sourceTarget(source,targets)
  if not canGuide() or not (C_Map and type(C_Map.GetMapInfo)=='function') then return nil end
  local candidates=targets and targets[(source[1] or ''):lower()];local zone=(source[3] or ''):lower();local best,matchID
  if not candidates or zone=='' then return nil end
  for _,candidate in ipairs(candidates) do
    local ok,info=pcall(C_Map.GetMapInfo,candidate.map);local name=ok and info and info.name
    if type(name)=='string' and name:lower()==zone then
      if matchID and matchID~=candidate.id then return nil end
      matchID=candidate.id
      if not best or candidate.distance<best.distance then best=candidate end
    end
  end
  return best
end
local sortedSources={}
local function getSources(item)
  if sortMode=='alphabetical' and sortedSources[item] then return sortedSources[item] end
  if sortMode=='nearest' and sortItem~=selected then local _,_,distances=nearestVendor(selected);sortDistances=distances or {};sortItem=selected end
  local others,vendors={},{}
  for _,source in ipairs(item.sources or {}) do
    local list=source[6]=='Sold by' and vendors or others;list[#list+1]=source
  end
  table.sort(vendors,function(a,b) local x,y=(a[1] or ''):lower(),(b[1] or ''):lower();if sortMode=='nearest' then local da,db=sortDistances[x],sortDistances[y];if da~=db then if not da then return false elseif not db then return true else return da<db end end end;local za,zb=(a[3] or ''):lower(),(b[3] or ''):lower();if za~=zb then return za<zb end;return x<y end)
  for _,source in ipairs(vendors) do others[#others+1]=source end
  if sortMode=='alphabetical' then sortedSources[item]=others end;return others
end
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
  local sources=getSources(item);local total=#item.drops+#sources;local _,_,_,targets=nearestVendor(selected)
  if total==0 then detailTitle:SetText(item.name..'  |  No captured sources');detailInfo:SetText('');return end
  dropOffset=math.max(0,math.min(dropOffset,math.max(0,total-DROP_PAGE)))
  detailTitle:SetText(item.name..'  |  #'..selected)
  detailInfo:SetText((dropOffset+1)..'-'..math.min(dropOffset+DROP_PAGE,total)..' of '..total)
  for i,row in ipairs(rows) do
    local index=dropOffset+i;local d=i<=DROP_PAGE and item.drops[index] or nil;local other=i<=DROP_PAGE and index>#item.drops and sources[index-#item.drops] or nil
    if d then
      local npc=MarketeerForeverFarmLookup.npcs[d[1]] or {'Unknown','Unknown','Unknown'}
      row.npcID=d[1];row.recipeItem=false;row.vendor=false;row.name:SetText(npc[1]);row.level:SetText(npc[2]);row.zone:SetText(npc[3]);row.rate:SetText(d[2] and string.format('%.2f%%',d[2]) or '--');row.sample:SetText(d[3] and tostring(d[3]) or '--');row.source:SetText(d[4] and 'Classic *' or 'Forever');row.view:SetText('Loot');row.view:SetEnabled(true);row:Show()
    elseif other then
      row.npcID=false;row.recipeItem=other[6]=='Created by' and core.HasItemRecipe and core.HasItemRecipe(selected) and selected or false;row.vendor=other[6]=='Sold by' and sourceTarget(other,targets) or false;row.name:SetText(other[1]);row.level:SetText(other[2]);row.zone:SetText(other[3]);row.rate:SetText(other[4] and string.format('%.2f%%',other[4]) or '--');row.sample:SetText(other[5] or '--');row.source:SetText(other[6]);row.view:SetText(other[6]=='Sold by' and 'Track' or row.recipeItem and 'Recipe' or 'Loot');row.view:SetEnabled(not not (row.vendor or row.recipeItem));row:Show()
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
  button(panel,'Nearest vendor',382,-102,125,guideToVendor)
  search:SetScript('OnEnterPressed',function(s)s:ClearFocus();find()end);search:SetScript('OnEscapePressed',function(s)s:ClearFocus()end)
  status=text(panel,18,-134,590)
  for i=1,ITEM_PAGE do
    local row=CreateFrame('Button',nil,panel,'BackdropTemplate');row:SetPoint('TOPLEFT',panel,'TOPLEFT',14,-154-(i-1)*22);row:SetSize(590,21);row:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8'});row:SetBackdropColor(i%2==0 and .12 or .08,.12,.12,.95)
    row.title=text(row,4,-4,420);row.count=text(row,430,-4,145)
    row.recipe=button(row,'Recipe',0,0,60,function()if row.itemID and core.ShowItemRecipes then core.ShowItemRecipes(row.itemID) end end);row.recipe:ClearAllPoints();row.recipe:SetPoint('RIGHT',row,'RIGHT',-2,0);row.recipe:SetSize(58,20)
    row:SetScript('OnClick',function(s)if s.itemID then selected=s.itemID;dropOffset=0;renderDrops()end end);choices[i]=row
  end
  local itemHint=text(panel,18,-251,350);itemHint:SetText('Scroll over items to browse')
  detailTitle=text(panel,18,-281,470,'GameFontNormal');detailInfo=text(panel,500,-282,105)
  local sortButton=button(panel,'Sort: Location A-Z',0,0,140,function(s)
    if sortMode=='alphabetical' then
      if not selected then status:SetText('Select an item first.');return end
      local _,err,distances=nearestVendor(selected);if not distances or not next(distances) then status:SetText(err or 'No vendor distances are available.');return end
      sortMode='nearest';sortItem=selected;sortDistances=distances;s:SetText('Sort: Nearest');status:SetText('Nearest known friendly vendors first; unknown locations follow.')
    else sortMode='alphabetical';sortItem=nil;sortDistances=nil;s:SetText('Sort: Location A-Z') end
    dropOffset=0;renderDrops()
  end)
  sortButton:ClearAllPoints();sortButton:SetPoint('TOPRIGHT',panel,'TOPRIGHT',-18,-275)
  local heads={};for i,name in ipairs({'SOURCE NAME','LEVEL','LOCATION','CHANCE','SAMPLES','TYPE'}) do heads[i]=text(panel,18,-302,80,'GameFontNormalSmall');heads[i]:SetText(name) end
  for i=1,MAX_DROPS do
    local row=CreateFrame('Frame',nil,panel,'BackdropTemplate');row:SetPoint('TOPLEFT',panel,'TOPLEFT',14,-320-(i-1)*22);row:SetSize(590,21);row:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8'});row:SetBackdropColor(i%2==0 and .12 or .08,.12,.12,.95)
    row.name=text(row,4,-4,175);row.level=text(row,180,-4,55);row.zone=text(row,240,-4,150);row.rate=text(row,395,-4,60);row.sample=text(row,460,-4,55);row.source=text(row,520,-4,65)
    row.view=button(row,'Loot',0,0,55,function()if row.vendor then trackVendor(row.vendor) elseif row.recipeItem and core.ShowItemRecipes then core.ShowItemRecipes(row.recipeItem) elseif row.npcID and core.ShowFarmMonster then core.ShowFarmMonster(row.npcID) end end);row.view:ClearAllPoints();row.view:SetPoint('RIGHT',row,'RIGHT',-2,0);row.view:SetSize(52,20);rows[i]=row
  end
  local hint=text(panel,18,-474,210);hint:SetText('Scroll over sources to browse');hint:ClearAllPoints();hint:SetPoint('BOTTOMLEFT',panel,'BOTTOMLEFT',18,27)
  local note=text(panel,240,-479,370);note:SetText('* Classic Era fallback. Snapshot may be incomplete.');note:ClearAllPoints();note:SetPoint('BOTTOMLEFT',panel,'BOTTOMLEFT',240,27)
  local function scrollItems(_,delta) itemOffset=itemOffset-delta;renderItems() end
  local function scrollSources(_,delta) dropOffset=dropOffset-delta;renderDrops() end
  for _,row in ipairs(choices) do row:EnableMouseWheel(true);row:SetScript('OnMouseWheel',scrollItems);row.recipe:EnableMouseWheel(true);row.recipe:SetScript('OnMouseWheel',scrollItems) end
  for _,row in ipairs(rows) do row:EnableMouseWheel(true);row:SetScript('OnMouseWheel',scrollSources);row.view:EnableMouseWheel(true);row.view:SetScript('OnMouseWheel',scrollSources) end
  panel:EnableMouseWheel(true);panel:SetScript('OnMouseWheel',function(_,delta)
    local _,cursorY=GetCursorPosition();local scale=panel:GetEffectiveScale();local y=cursorY/scale;local top=panel:GetTop()
    if top and y>top-275 then scrollItems(nil,delta) else scrollSources(nil,delta) end
  end)
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
