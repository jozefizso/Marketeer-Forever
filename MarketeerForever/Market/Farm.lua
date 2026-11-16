local core=MarketeerForeverCore
local panel,levelBox,searchBox,status,footer,detailTitle,detailInfo,sortButton
local mapMenu,mapMenuRows
local rows,detailRows={},{}
local results,prices={},{}
local selected,offset,detailOffset=nil,0,0
local maxScore=0
local sortMode='score'
local PAGE,DETAIL=6,3
local MAX_DETAIL=12
local spawnIcon='|A:Waypoint-MapPin-Untracked:14:14|a'
local function money(n)
  if type(n)~='number' then return '--' end
  n=math.floor(n+.5);local g=math.floor(n/10000);local s=math.floor(n%10000/100);local c=n%100
  if g>0 then return g..'g '..s..'s '..c..'c' end
  if s>0 then return s..'s '..c..'c' end
  return c..'c'
end
local function points(n)
  if type(n)~='number' then return '--' end
  return string.format('%.1f',maxScore>0 and 100*n/maxScore or 0)
end
local function label(parent,x,y,width,font)
  local t=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall');t:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);t:SetWidth(width);t:SetJustifyH('LEFT');t:SetWordWrap(false);return t
end
local function button(parent,text,x,y,width,action)
  local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetPoint('TOPLEFT',parent,'TOPLEFT',x,y);b:SetSize(width,23);b:SetText(text);b:SetScript('OnClick',action);return b
end
local function explain(parent,anchor,x,title,lines)
  local icon=CreateFrame('Button',nil,parent);icon:SetSize(16,16);icon:SetPoint('LEFT',anchor,'LEFT',x,0)
  local mark=icon:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');mark:SetPoint('CENTER');mark:SetText('|cff82cfa1[?]|r')
  icon:SetScript('OnEnter',function(s)
    if not GameTooltip then return end
    GameTooltip:SetOwner(s,'ANCHOR_RIGHT');GameTooltip:AddLine(title)
    for _,line in ipairs(lines) do GameTooltip:AddLine(line,1,1,1,true) end
    GameTooltip:Show()
  end)
  icon:SetScript('OnLeave',function()if GameTooltip then GameTooltip:Hide() end end)
  return icon
end
local function market(id) return prices[id] end
local function renderDetail()
  for _,row in ipairs(detailRows) do row:Hide() end
  if not selected then detailTitle:SetText('Select a monster to inspect its loot');detailInfo:SetText('');return end
  local data=MarketeerForeverFarmScore.Mob(selected.mob,market,true)
  table.sort(data.entries,function(a,b)
    local x,y=a.score or -1,b.score or -1
    if x==y then return (a.gross or -1)>(b.gross or -1) end
    return x>y
  end)
  detailOffset=math.max(0,math.min(detailOffset,math.max(0,#data.entries-DETAIL)))
  detailTitle:SetText(selected.mob.name..' | Level '..tostring(selected.mob.level or '?')..' | '..selected.mob.location)
  detailInfo:SetText((detailOffset+1)..'-'..math.min(detailOffset+DETAIL,#data.entries)..' of '..#data.entries..' drops')
  for i,row in ipairs(detailRows) do
    local entry=i<=DETAIL and data.entries[detailOffset+i] or nil
    if entry then
      local d=entry.drop;local known=MarketeerForeverFarmLookup and MarketeerForeverFarmLookup.items[d[1]];row.itemID=d[1];row.name:SetText(MarketeerForeverFarmData.items[d[1]] or (known and known.name) or ('Item #'..d[1]));row.rate:SetText((d[2] and string.format('%.2f%%',d[2]) or '--')..' ('..(d[4] and tostring(d[4]) or '?')..')'..(d[5] and ' *' or ''));row.sales:SetText(entry.market.sales~=nil and string.format('%.1f',entry.market.sales) or '--');row.price:SetText(money(entry.market.price));row.score:SetText(points(entry.score));row:Show()
    else row.itemID=nil;row:Hide() end
  end
end
local function render()
  offset=math.max(0,math.min(offset,math.max(0,#results-PAGE)))
  for i,row in ipairs(rows) do
    local v=results[offset+i]
    if v then
      local hasSpawns=core.FarmHasSpawnReferences and core.FarmHasSpawnReferences(v.id)
      row.entry=v;row.name:SetText((hasSpawns and (spawnIcon..' ') or '')..v.mob.name);row.level:SetText(v.mob.level);row.zone:SetText(v.mob.location);row.value:SetText(money(v.gross));row.score:SetText(points(v.score));row.coverage:SetText(v.scored..'/'..#v.mob.drops);row.map:SetText(hasSpawns and 'Map' or 'No pins');row:Show()
    else row.entry=nil;row:Hide() end
  end
  footer:SetText(#results==0 and 'No results with the current filters and price data.' or ((offset+1)..'-'..math.min(offset+PAGE,#results)..' of '..#results..' | Coverage: scored drops / recorded drops (20+ observations).'))
  renderDetail()
end
local function refresh(preserve)
  if not panel or not panel:IsShown() then return end
  local previous,previousOffset,previousDetail=preserve and selected or nil,offset,detailOffset
  local input=levelBox:GetText();local maxLevel=tonumber(input)
  if input=='' or maxLevel==0 then maxLevel=math.huge elseif not maxLevel or maxLevel<0 then status:SetText('Enter a maximum level, or leave it blank for all levels.');results={};render();return end
  prices={}
  local marketKey,marketError=core.Market()
  local book=marketKey and MarketeerForeverCoreDB and MarketeerForeverCoreDB.prices and MarketeerForeverCoreDB.prices[marketKey]
  if not book or type(book.items)~='table' then status:SetText(marketError or 'No AH scan for this market. Scan the auction house first.');results={};render();return end
  local activityMarket,activityError=MarketeerForeverMarketActivityMarket()
  local info=activityMarket and MarketeerForeverAPI.GetTableInfo()
  local infoMarket=info and type(info.market)=='string' and info.market:lower():gsub('/','.')
  prices={}
  for id,row in pairs(book.items) do
    if type(id)=='number' and type(row)=='table' and not row.carried and type(row.price)=='number' and row.price>0 then
      local activity=activityMarket and infoMarket==activityMarket and MarketeerForeverAPI.GetPrice(id)
      local itemMarket=activity and type(activity.market)=='string' and activity.market:lower():gsub('/','.')
      prices[id]={price=row.price,sales=activity and itemMarket==activityMarket and activity.soldPerDay or nil}
    end
  end
  local query=searchBox:GetText():lower();results={};selected=nil;detailOffset=0;maxScore=0
  for id,mob in pairs(MarketeerForeverFarmData.mobs) do
    if mob.max<=maxLevel then
      local v=MarketeerForeverFarmScore.Mob(mob,market);v.id=id;v.mob=mob
      if v.score and v.score>maxScore then maxScore=v.score end
      if v.gross and (query=='' or mob.name:lower():find(query,1,true) or mob.location:lower():find(query,1,true)) then results[#results+1]=v end
    end
  end
  table.sort(results,function(a,b)
    local x,y;if sortMode=='score' then x,y=a.score,b.score else x,y=a.gross,b.gross end
    if x==nil and y~=nil then return false elseif y==nil and x~=nil then return true end
    if x==y then return a.mob.name<b.mob.name end
    return x>y
  end)
  offset=0
  if preserve then
    offset=previousOffset
    if previous then
      for _,entry in ipairs(results) do if entry.id==previous.id then selected=entry;break end end
      if not selected then selected=previous end
      detailOffset=previousDetail
    end
  end
  local age=book.observed and math.max(0,math.floor(((GetServerTime and GetServerTime() or time())-book.observed)/60)) or nil
  status:SetText('Last scan: '..(age and (age..' min ago') or 'age unknown')..' | '..(infoMarket==activityMarket and activityMarket and ('Demand: '..activityMarket) or ('Demand unavailable: '..tostring(activityError or 'run updater'))))
  sortButton:SetText(sortMode=='score' and 'Sort: Score' or 'Sort: Value');render()
end
function core.SelectFarmMonster(id,observedLevel)
  if not panel then return end
  id=tonumber(id);local source=MarketeerForeverFarmLookup and MarketeerForeverFarmLookup.npcs[id]
  local mob=MarketeerForeverFarmData.mobs[id]
  if source then
    local full={name=source[1],level=source[2],location=source[3],drops={}}
    for itemId,item in pairs(MarketeerForeverFarmLookup.items) do for _,drop in ipairs(item.drops) do if drop[1]==id then full.drops[#full.drops+1]={itemId,drop[2],0,drop[3],drop[4]};break end end end
    if #full.drops>0 then mob=full end
  end
  if not mob then status:SetText('No loot data was captured for this monster.');return end
  local level=type(observedLevel)=='number' and observedLevel>=1 and observedLevel<=100 and observedLevel or nil
  local ranked=MarketeerForeverFarmData.mobs[id]
  if not level and ranked and type(ranked.max)=='number' and ranked.max>0 then level=ranked.max end
  if not level then local low,high=tostring(mob.level or ''):match('(%d+)%s*%-%s*(%d+)');level=tonumber(high or low or tostring(mob.level or ''):match('%d+')) end
  searchBox:SetText(mob.name);levelBox:SetText(level and tostring(level) or '')
  refresh()
  local pos
  for i,v in ipairs(results) do if v.id==id then pos=i;break end end
  if not pos then local v=MarketeerForeverFarmScore.Mob(mob,market);v.id=id;v.mob=mob;table.insert(results,1,v);pos=1 end
  offset=math.max(0,math.min(pos-1,math.max(0,#results-PAGE)))
  selected={id=id,mob=mob};detailOffset=0;render()
  status:SetText('Showing '..mob.name..'; max level '..(level and tostring(level) or 'not known')..'. Prices depend on the last scan.')
end
function core.CreateFarmPanel(parent)
  if panel then return panel end
  panel=CreateFrame('Frame',nil,parent);panel:SetAllPoints();panel:Hide()
  label(panel,18,-73,550,'GameFontNormalLarge'):SetText('FARM  |  MONSTER LOOT')
  label(panel,280,-77,350,'GameFontHighlightSmall'):SetText('|cff9db9a5OpenMap required  |  '..spawnIcon..' = Classic spawn data|r')
  label(panel,18,-108,60):SetText('Max level')
  levelBox=CreateFrame('EditBox',nil,panel,'InputBoxTemplate');levelBox:SetSize(42,24);levelBox:SetPoint('TOPLEFT',panel,'TOPLEFT',88,-102);levelBox:SetAutoFocus(false);levelBox:SetNumeric(true);levelBox:SetMaxLetters(3);levelBox:SetText('')
  label(panel,148,-108,40):SetText('Search')
  searchBox=CreateFrame('EditBox',nil,panel,'InputBoxTemplate');searchBox:SetSize(115,24);searchBox:SetPoint('TOPLEFT',panel,'TOPLEFT',195,-102);searchBox:SetAutoFocus(false);searchBox:SetMaxLetters(60)
  button(panel,'Refresh',325,-102,75,function()refresh()end)
  sortButton=button(panel,'Sort: Score',410,-102,105,function()sortMode=sortMode=='score' and 'gross' or 'score';refresh()end)
  local help=button(panel,'?',525,-102,28,function()end)
  help:SetScript('OnEnter',function(s)if GameTooltip then GameTooltip:SetOwner(s,'ANCHOR_RIGHT');GameTooltip:AddLine('Farm score');GameTooltip:AddLine('0–100 versus the best eligible monster. Volume weight is estimated sales/day divided by 300, capped at 100%: 16/day gets 5%, 150/day gets 50%, and 300/day or more gets full weight. Listed supply is not used. This is a ranking heuristic, not a sale probability.',1,1,1,true);GameTooltip:AddLine('Missing demand is excluded; zero sales scores zero. Uncertain drop rates are discounted. Coverage shows how many drops contributed.',1,.8,.3,true);GameTooltip:Show()end end)
  help:SetScript('OnLeave',function()if GameTooltip then GameTooltip:Hide()end end)
  levelBox:SetScript('OnEnterPressed',function(s)s:ClearFocus();refresh()end);searchBox:SetScript('OnEnterPressed',function(s)s:ClearFocus();refresh()end)
  levelBox:SetScript('OnEscapePressed',function(s)s:ClearFocus()end);searchBox:SetScript('OnEscapePressed',function(s)s:ClearFocus()end)
  status=label(panel,18,-134,590)
  local headers={{'MONSTER',18,155},{'LVL',175,42},{'LOCATION',220,125},{'VALUE',350,72},{'SCORE',425,72},{'COVERAGE',505,95}}
  local topHeaders={}
  for i,v in ipairs(headers) do topHeaders[i]=label(panel,v[2],-154,v[3],'GameFontNormalSmall');topHeaders[i]:SetText(v[1]) end
  explain(panel,topHeaders[5],49,'Monster score',{
    'A ranking from 0 to 100. The highest-scoring monster within your maximum level gets 100; other monsters are compared to it.',
    'Each drop starts with its estimated value per kill. We favor items that sell more often: 300 estimated sales per day receives full weight, while 150 receives half and 16 receives about 5%.',
    'We also reduce uncertain drop rates and apply a 5% auction cut. The score is not gold, a sale guarantee, or an estimate for 100 kills.'})
  explain(panel,topHeaders[6],66,'Score coverage',{
    'Scored drops / recorded drops. For example, 58/110 means 58 of 110 recorded drops contributed to this monster’s score.',
    'A drop needs a price from your last AH scan, estimated sales per day, and at least 20 observations. Missing data is excluded; zero sales is known data and contributes zero points.',
    'More coverage means the score includes more of the recorded loot table, but it does not guarantee the table is complete.'})
  local mapHeader=label(panel,0,-154,48,'GameFontNormalSmall');mapHeader:SetText('MAP')
  mapMenu=CreateFrame('Frame',nil,panel,'BackdropTemplate');mapMenu:SetSize(220,210);mapMenu:SetFrameLevel(panel:GetFrameLevel()+30);mapMenu:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1});mapMenu:SetBackdropColor(.055,.075,.065,.99);mapMenu:SetBackdropBorderColor(.25,.48,.34,1);mapMenu:EnableMouse(true);mapMenu:Hide()
  label(mapMenu,10,-10,190,'GameFontNormalSmall'):SetText('CHOOSE A ZONE')
  mapMenuRows={}
  for i=1,7 do
    local zoneButton=button(mapMenu,'',10,-27-(i-1)*24,200,function(s)
      if not s.zone or not mapMenu.npcID then return end
      local success,err=core.FarmMapOpen(mapMenu.npcID,s.zone);mapMenu:Hide();if not success then status:SetText(err) end
    end);mapMenuRows[i]=zoneButton
  end
  local function showMap(row)
    if not row.entry then return end
    if not selected or selected.id~=row.entry.id then selected=row.entry;detailOffset=0;renderDetail() end
    local zones=core.FarmMapZones(row.entry.mob.location)
    if #zones==0 then status:SetText('No matching map is available for this creature’s recorded locations.');return end
    if #zones==1 then local ok,err=core.FarmMapOpen(row.entry.id,zones[1]);if not ok then status:SetText(err) end;return end
    mapMenu.npcID=row.entry.id;mapMenu:ClearAllPoints();mapMenu:SetPoint('TOPRIGHT',row.map,'BOTTOMRIGHT',0,-2)
    for i,b in ipairs(mapMenuRows) do b.zone=zones[i];if b.zone then b:SetText(b.zone.name);b:Show() else b:Hide() end end
    mapMenu:SetHeight(35+math.min(#zones,#mapMenuRows)*24);mapMenu:Show()
  end
  for i=1,PAGE do
    local row=CreateFrame('Button',nil,panel,'BackdropTemplate');row:SetPoint('TOPLEFT',panel,'TOPLEFT',14,-172-(i-1)*23);row:SetSize(590,22);row:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8'});row:SetBackdropColor(i%2==0 and .12 or .08,.12,.12,.95)
    row.name=label(row,4,-4,152);row.level=label(row,161,-4,42);row.zone=label(row,206,-4,125);row.value=label(row,336,-4,72);row.score=label(row,411,-4,72);row.coverage=label(row,491,-4,90)
    row.map=button(row,'Map',0,0,50,function()showMap(row)end);row.map:ClearAllPoints();row.map:SetPoint('RIGHT',row,'RIGHT',-2,0);row.map:SetSize(48,20)
    row.map:SetScript('OnEnter',function(s)if GameTooltip then GameTooltip:SetOwner(s,'ANCHOR_RIGHT');GameTooltip:AddLine('Open recorded location on OpenMap');GameTooltip:AddLine('Requires the OpenMap addon to be installed and enabled.',1,1,1,true);if row.entry and core.FarmHasSpawnReferences and core.FarmHasSpawnReferences(row.entry.id) then GameTooltip:AddLine('Classic spawn references exist for this creature, but may not cover every listed zone or match Forever.',1,1,1,true) else GameTooltip:AddLine('No spawn coordinates were captured for this creature. The map can still open its recorded zone without markers.',1,.8,.3,true) end;GameTooltip:Show()end end);row.map:SetScript('OnLeave',function()if GameTooltip then GameTooltip:Hide()end end)
    row:SetScript('OnClick',function(s)mapMenu:Hide();selected=s.entry;detailOffset=0;renderDetail()end);rows[i]=row
  end
  footer=label(panel,18,-316,590)
  button(panel,'Previous',18,-335,75,function()offset=offset-PAGE;render()end);button(panel,'Next',100,-335,75,function()offset=offset+PAGE;render()end)
  local note=label(panel,190,-340,405);note:SetText('Value / score per kill; click a monster for loot.')
  note:SetText('Score: 0–100 vs best monster at this max level.')
  detailTitle=label(panel,18,-366,590,'GameFontNormal');detailInfo=label(panel,500,-367,100)
  local detailHeaders={}
  for i,v in ipairs({{'ITEM',18,190},{'DROP % (N)',214,105},{'SALES/DAY',324,75},{'PRICE',404,82},{'SCORE',494,105}}) do
    detailHeaders[i]=label(panel,v[2],-388,v[3],'GameFontNormalSmall');detailHeaders[i]:SetText(v[1])
  end
  explain(panel,detailHeaders[5],49,'Drop score contribution',{
    'This number is how many points this item contributes to the selected monster’s score. Contributions add up to the monster score, allowing for rounding.',
    'It uses the item’s drop rate, last-scan price and estimated sales per day. Values under 300 sales per day receive proportionally less weight.',
    'A dash means the data needed to score this drop is missing, or there are fewer than 20 observations.'})
  for i=1,MAX_DETAIL do
    local row=CreateFrame('Frame',nil,panel,'BackdropTemplate');row:SetPoint('TOPLEFT',panel,'TOPLEFT',14,-403-(i-1)*22);row:SetSize(590,21);row:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8'});row:SetBackdropColor(i%2==0 and .12 or .08,.12,.12,.95)
    row.name=label(row,4,-4,190);row.rate=label(row,200,-4,105);row.sales=label(row,310,-4,75);row.price=label(row,390,-4,82);row.score=label(row,480,-4,105)
    row:EnableMouse(true);row:SetScript('OnEnter',function(s)if s.itemID and GameTooltip then GameTooltip:SetOwner(s,'ANCHOR_RIGHT');GameTooltip:SetItemByID(s.itemID);GameTooltip:AddLine('* Classic Era fallback where marked; parentheses = observations.',1,1,1,true);GameTooltip:Show()end end);row:SetScript('OnLeave',function()if GameTooltip then GameTooltip:Hide()end end);detailRows[i]=row
  end
  local prevLoot=button(panel,'Previous loot',18,-474,110,function()detailOffset=detailOffset-DETAIL;renderDetail()end);local nextLoot=button(panel,'Next loot',136,-474,90,function()detailOffset=detailOffset+DETAIL;renderDetail()end)
  prevLoot:ClearAllPoints();prevLoot:SetPoint('BOTTOMLEFT',panel,'BOTTOMLEFT',18,22);nextLoot:ClearAllPoints();nextLoot:SetPoint('BOTTOMLEFT',panel,'BOTTOMLEFT',136,22)
  local disclaimer=label(panel,240,-479,365);disclaimer:SetText('1 per drop assumed; * Classic Era. Sales not guaranteed.');disclaimer:ClearAllPoints();disclaimer:SetPoint('BOTTOMLEFT',panel,'BOTTOMLEFT',240,27)
  local function layout()
    local width=math.max(590,(panel:GetWidth() or 620)-42)
    DETAIL=math.max(3,math.min(MAX_DETAIL,math.floor(((panel:GetHeight() or 520)-445)/22)))
    local dataWidth=width-56
    mapHeader:ClearAllPoints();mapHeader:SetPoint('TOPLEFT',panel,'TOPLEFT',18+dataWidth+7,-154)
    local top={0,.265,.34,.56,.71,.835,1};local bottom={0,.33,.51,.65,.80,1}
    local topKeys={'name','level','zone','value','score','coverage'};local detailKeys={'name','rate','sales','price','score'}
    for i,h in ipairs(topHeaders) do h:ClearAllPoints();h:SetPoint('TOPLEFT',panel,'TOPLEFT',18+dataWidth*top[i],-154);h:SetWidth(dataWidth*(top[i+1]-top[i])-5) end
    for _,row in ipairs(rows) do row:SetWidth(width);for i,key in ipairs(topKeys) do local t=row[key];t:ClearAllPoints();t:SetPoint('TOPLEFT',row,'TOPLEFT',4+dataWidth*top[i],-4);t:SetWidth(dataWidth*(top[i+1]-top[i])-5) end end
    for i,h in ipairs(detailHeaders) do h:ClearAllPoints();h:SetPoint('TOPLEFT',panel,'TOPLEFT',18+width*bottom[i],-388);h:SetWidth(width*(bottom[i+1]-bottom[i])-5) end
    for _,row in ipairs(detailRows) do row:SetWidth(width);for i,key in ipairs(detailKeys) do local t=row[key];t:ClearAllPoints();t:SetPoint('TOPLEFT',row,'TOPLEFT',4+width*bottom[i],-4);t:SetWidth(width*(bottom[i+1]-bottom[i])-5) end end
    if selected then renderDetail() end
  end
  panel:SetScript('OnSizeChanged',layout)
  layout()
  panel:SetScript('OnShow',function()refresh(true)end)
  return panel
end
core.Subscribe(function(event)if event=='complete' and panel and panel:IsShown() then refresh(true)end end)
