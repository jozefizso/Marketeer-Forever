-- Classic spawn locations are approximate references, not verified Forever spawns.
local core=MarketeerForeverCore
local fallback={['alterac mountains']=1416,['arathi highlands']=1417,['badlands']=1418,['blasted lands']=1419,['tirisfal glades']=1420,['silverpine forest']=1421,['western plaguelands']=1422,['eastern plaguelands']=1423,['hillsbrad foothills']=1424,['the hinterlands']=1425,['dun morogh']=1426,['searing gorge']=1427,['burning steppes']=1428,['elwynn forest']=1429,['deadwind pass']=1430,['duskwood']=1431,['loch modan']=1432,['redridge mountains']=1433,['stranglethorn vale']=1434,['swamp of sorrows']=1435,['westfall']=1436,['wetlands']=1437,['durotar']=1411,['mulgore']=1412,['the barrens']=1413,['teldrassil']=1438,['darkshore']=1439,['ashenvale']=1440,['thousand needles']=1441,['stonetalon mountains']=1442,['desolace']=1443,['feralas']=1444,['dustwallow marsh']=1445,['tanaris']=1446,['azshara']=1447,['felwood']=1448,["un'goro crater"]=1449,['moonglade']=1450,['silithus']=1451,['winterspring']=1452,['riverglades']=2548,['zephras isle']=2521}
-- OpenMap's Forever entrance positions; show the outdoor entrance, not a fabricated spawn.
local entrances={['shadowfang keep']={1421,0,-231,1571.6},['blackfathom deeps']={1440,1,4249.1,748.4},['wailing caverns']={1413,1,-751.1,-2209.2},['razorfen kraul']={1413,1,-4459.4,-1660.2},['the deadmines']={1436,0,-11207.8,1681.2},['deadmines']={1436,0,-11207.8,1681.2}}
local mapNames
local function trim(s)return s:match('^%s*(.-)%s*$')end
local function names()
  if mapNames then return mapNames end
  mapNames={};for name,id in pairs(fallback) do mapNames[name]=id end
  if C_Map and C_Map.GetMapChildrenInfo then
    for _,root in ipairs({946,1414,1415}) do
      local ok,children=pcall(C_Map.GetMapChildrenInfo,root,nil,true)
      if ok and type(children)=='table' then for _,info in ipairs(children) do
        if type(info.name)=='string' and type(info.mapID)=='number' and (not issecretvalue or (not issecretvalue(info.name) and not issecretvalue(info.mapID))) and not mapNames[info.name:lower()] then mapNames[info.name:lower()]=info.mapID end
      end end
    end
  end
  return mapNames
end
function core.FarmMapZones(location)
  local out,seen={},{};if type(location)~='string' then return out end
  for part in location:gmatch('[^,]+') do
    local label=trim(part);local key=label:lower();local entrance=entrances[key];local id=entrance and entrance[1] or names()[key]
    if not id then local tail=label:match(':%s*(.+)$') or label:match('%s%-%s(.+)$');if tail then label=trim(tail);id=names()[label:lower()] end end
    if id and not seen[id] then seen[id]=true;out[#out+1]={name=label,id=id,entrance=entrance} end
  end
  return out
end
-- This indicates creature-wide reference data, not a guarantee for every zone.
function core.FarmHasSpawnReferences(npcID)
  local points=MarketeerForeverFarmSpawns and MarketeerForeverFarmSpawns[npcID]
  return type(points)=='table' and #points>0
end
-- Own the marker frames, using OpenMap's public canvas API rather than modifying OpenMap.
local markers,selected={},nil
local function clearMarkers() for _,pin in ipairs(markers) do pin:Hide() end end
local function refreshMarkers()
  clearMarkers()
  local api,map=OpenMapAPI,WorldMapFrame
  if not selected or not api or not api.IsStitched() or not map or not map.GetCanvas then return 0 end
  local canvas=map:GetCanvas();local host=map:GetMapID()
  if not canvas or not host then return 0 end
  -- Resize the marker, not its frame scale: scaling the frame also scales
  -- SetPoint offsets and makes the marker drift away from its map location.
  local canvasScale=canvas.GetEffectiveScale and canvas:GetEffectiveScale()
  local uiScale=UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()
  local pinScale=canvasScale and canvasScale>0 and uiScale and uiScale>0 and uiScale/canvasScale or 1
  local count=0
  local minU,maxU,minV,maxV
  for _,point in ipairs(selected.points) do
    local x,y=api.CanvasFromWorldPos(point[1],point[2],point[3])
    if x and y then
      local u,v=api.WorldFromMap(host,x,y)
      local zx,zy;if u then zx,zy=api.MapFromWorld(selected.zone,u,v) end
      if zx and zy and zx>=0 and zx<=1 and zy>=0 and zy<=1 then
        minU=not minU and u or math.min(minU,u);maxU=not maxU and u or math.max(maxU,u)
        minV=not minV and v or math.min(minV,v);maxV=not maxV and v or math.max(maxV,v)
        count=count+1;local pin=markers[count]
        if not pin then
          pin=CreateFrame('Frame',nil,canvas);pin:SetSize(12,12);pin:EnableMouse(true)
          if pin.SetMouseClickEnabled then pin:SetMouseClickEnabled(false) end
          pin:SetScript('OnEnter',function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:AddLine(self.creatureName or 'Creature',1,.82,0)
            GameTooltip:AddLine('Approximate Classic spawn reference; locations may differ in Forever.',1,1,1,true);GameTooltip:Show()
          end)
          pin:SetScript('OnLeave',function(self)if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
          pin:SetScript('OnHide',function(self)if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
          local icon=pin:CreateTexture(nil,'OVERLAY');icon:SetAllPoints()
          -- Use the game's normal map pin without a custom color tint.
          local atlas='Waypoint-MapPin-Untracked'
          local atlasAvailable=icon.SetAtlas and (not C_Texture or not C_Texture.GetAtlasInfo or C_Texture.GetAtlasInfo(atlas))
          local ok=atlasAvailable and pcall(icon.SetAtlas,icon,atlas,false)
          if not ok then icon:SetTexture('Interface\\TargetingFrame\\UI-RaidTargetingIcon_8') end
          markers[count]=pin
        end
        pin.creatureName=selected.name;pin:SetSize(12*pinScale,12*pinScale);pin:SetFrameLevel((api.ArtTopLevel() or 0)+1);pin:ClearAllPoints();pin:SetPoint('CENTER',canvas,'TOPLEFT',canvas:GetWidth()*x,-canvas:GetHeight()*y);pin:Show()
      end
    end
  end
  if count>0 then return count,(minU+maxU)/2,(minV+maxV)/2 end
  return 0
end
local callbackOwner={}
local callbacksRegistered=false
local restoreMenu,hookedMap=false,nil
local function armMenuRestore(map)
  if not map or not map.HookScript then return end
  if hookedMap~=map then
    map:HookScript('OnHide',function(self)
      if not restoreMenu then return end
      restoreMenu=false
      local function reopen()
        if self.IsShown and self:IsShown() then return end
        if MarketeerForeverMenu and MarketeerForeverMenu.IsShown and MarketeerForeverMenu:IsShown() then return end
        if core.OpenTradingMenu then core.OpenTradingMenu() end
      end
      -- Wait until the map's close/escape handling has finished.
      if C_Timer and C_Timer.After then C_Timer.After(0,reopen) else reopen() end
    end)
    hookedMap=map
  end
  restoreMenu=true
end
function core.FarmMapOpen(npcID,zone)
  if InCombatLockdown and InCombatLockdown() then return false,'Open the map after combat.' end
  if not OpenMapAPI or (OpenMapAPI.version or 0)<2 or not OpenMapAPI.RegisterCallback then return false,'Map requires OpenMap. Install or update the OpenMap addon, enable it, then reload.' end
  if not C_Map or not C_Map.OpenWorldMap then return false,'World map API is unavailable.' end
  local wasVisible=MarketeerForeverMenu and MarketeerForeverMenu.IsShown and MarketeerForeverMenu:IsShown()
  restoreMenu=false
  local ok=pcall(C_Map.OpenWorldMap,zone.id)
  if not ok then return false,'Could not open this zone map.' end
  if wasVisible and WorldMapFrame and WorldMapFrame.IsShown and WorldMapFrame:IsShown() then
    armMenuRestore(WorldMapFrame)
    if MarketeerForeverMenu.Hide then MarketeerForeverMenu:Hide() end
  end
  local points=(MarketeerForeverFarmSpawns and MarketeerForeverFarmSpawns[npcID]) or {}
  local mob=MarketeerForeverFarmData and MarketeerForeverFarmData.mobs[npcID]
  local name=mob and mob.name or 'Creature'
  selected={zone=zone.id,points=points,name=name}
  local request=selected
  clearMarkers()
  if not callbacksRegistered then
    OpenMapAPI.RegisterCallback(callbackOwner,'OpenMap_ViewChanged',refreshMarkers)
    OpenMapAPI.RegisterCallback(callbackOwner,'OpenMap_StitchedChanged',refreshMarkers)
    callbacksRegistered=true
  end
  local attempts=0
  local function draw()
    if selected~=request then return end
    attempts=attempts+1
    if not OpenMapAPI.IsStitched() and attempts<20 and C_Timer and C_Timer.After then C_Timer.After(.25,draw);return end
    if not OpenMapAPI.IsStitched() then print('Marketeer: OpenMap’s stitched map is unavailable; no area markers were placed.');return end
    if zone.entrance and WorldMapFrame and WorldMapFrame.GetMapID and OpenMapAPI.CanvasFromWorldPos and OpenMapAPI.WorldFromMap and OpenMapAPI.ShowWorld then
      local p=zone.entrance;local x,y=OpenMapAPI.CanvasFromWorldPos(p[2],p[3],p[4]);local u,v;if x and y then u,v=OpenMapAPI.WorldFromMap(WorldMapFrame:GetMapID(),x,y) end
      if u and v then OpenMapAPI.ShowWorld(u,v) end
    end
    local success,count,centerU,centerV=pcall(refreshMarkers)
    if success and count>0 then
      if type(OpenMapAPI.ShowWorld)=='function' then pcall(OpenMapAPI.ShowWorld,centerU,centerV) end
      print('Marketeer: '..count..' Classic reference locations shown on OpenMap; Forever spawns may differ.')
    elseif success then print('Marketeer: no Classic reference locations in '..zone.name..'; no area markers were placed.')
    else print('Marketeer: could not display OpenMap markers.') end
  end
  if C_Timer and C_Timer.After then C_Timer.After(.25,draw) else draw() end
  return true
end
