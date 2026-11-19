-- A small pinned creature card; mouse interaction is confined to this frame.
local core=MarketeerForeverCore
local card=CreateFrame('Frame',nil,UIParent,'BackdropTemplate')
card:SetSize(390,359);card:SetFrameStrata('TOOLTIP');card:SetClampedToScreen(true);card:EnableMouse(true);card:SetMovable(true);card:RegisterForDrag('LeftButton')
card:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1})
card:SetBackdropColor(.045,.075,.055,.98);card:SetBackdropBorderColor(.28,.53,.35,1);card:Hide()
local function text(x,y,width,font)
  local t=card:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall');t:SetPoint('TOPLEFT',card,'TOPLEFT',x,y);t:SetWidth(width);t:SetJustifyH('LEFT');t:SetWordWrap(false);return t
end
local accent=card:CreateTexture(nil,'ARTWORK');accent:SetColorTexture(.35,.78,.46,1);accent:SetPoint('TOPLEFT',card,'TOPLEFT',12,-10);accent:SetPoint('TOPRIGHT',card,'TOPRIGHT',-12,-10);accent:SetHeight(2)
local kicker=text(14,-19,300,'GameFontNormalSmall');kicker:SetText('|cff8fca94FARM  /  CREATURE SNAPSHOT|r')
local name=text(14,-38,350,'GameFontNormal');local context=text(14,-58,350)
local valueLabel=text(14,-78,155);valueLabel:SetText('EST. LOOT VALUE / KILL')
local value=text(14,-94,155,'GameFontNormalLarge')
local coverage=text(180,-83,145);local age=text(180,-100,145)
local net=text(14,-114,160)
local skin=text(14,-132,345);local combined=text(14,-149,345)
local skinLabel=text(14,-168,100,'GameFontNormalSmall');skinLabel:SetText('SKINNING')
local skinIcons={}
for i=1,8 do
  local button=CreateFrame('Button',nil,card);button:SetSize(28,28);button:SetPoint('TOPLEFT',card,'TOPLEFT',14+(i-1)*44,-183)
  button.icon=button:CreateTexture(nil,'ARTWORK');button.icon:SetAllPoints(button)
  button.chance=button:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');button.chance:SetPoint('TOP',button,'BOTTOM',0,-1)
  button:SetScript('OnEnter',function(self)if self.itemID and GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetHyperlink('item:'..self.itemID);GameTooltip:Show() end end)
  button:SetScript('OnLeave',function(self)if GameTooltip and (not GameTooltip.GetOwner or GameTooltip:GetOwner()==self) then GameTooltip:Hide() end end)
  button:Hide();skinIcons[i]=button
end
local divider=card:CreateTexture(nil,'ARTWORK');divider:SetColorTexture(.22,.35,.25,1);divider:SetPoint('TOPLEFT',card,'TOPLEFT',14,-223);divider:SetPoint('TOPRIGHT',card,'TOPRIGHT',-14,-223);divider:SetHeight(1)
local columns={{key='name',title='DROP',x=14,width=160},{key='rate',title='CHANCE',x=178,width=54},{key='price',title='AH PRICE',x=235,width=73},{key='sales',title='SALES/D',x=312,width=64}}
for _,col in ipairs(columns) do text(col.x,-231,col.width,'GameFontNormalSmall'):SetText(col.title) end
local lines={};for i=1,3 do local row={};for _,col in ipairs(columns) do row[col.key]=text(col.x,-248-(i-1)*17,col.width) end;lines[i]=row end
local note=text(14,-306,360);note:SetText('|cff91a99a1 per drop/skin; assumes sales. No deposits.|r')
local shownID,shownLevel,dismissedID,dragging,userPositioned
local toggled=false
local function modifier()
  local key=MarketeerForeverCoreDB and MarketeerForeverCoreDB.farmHoverKey
  if key=='CTRL' or key=='ALT' or key=='OFF' then return key end
  return 'SHIFT'
end
local function modifierDown()
  local key=modifier()
  if (not MarketeerForeverCoreDB or MarketeerForeverCoreDB.farmHoverNoCombat~=false) and InCombatLockdown and InCombatLockdown() then return false end
  if key=='CTRL' then return IsControlKeyDown and IsControlKeyDown() end
  if key=='ALT' then return IsAltKeyDown and IsAltKeyDown() end
  return key=='SHIFT' and IsShiftKeyDown and IsShiftKeyDown()
end
local function toggleMode() return MarketeerForeverCoreDB and MarketeerForeverCoreDB.farmHoverToggle==true end
local function snapshotActive()
  if (not MarketeerForeverCoreDB or MarketeerForeverCoreDB.farmHoverNoCombat~=false) and InCombatLockdown and InCombatLockdown() then return false end
  if modifier()=='OFF' then return false end
  return toggleMode() and toggled or (not toggleMode() and modifierDown())
end
card:SetScript('OnDragStart',function(self)
  if snapshotActive() then dragging=true;self:StartMoving() end
end)
card:SetScript('OnDragStop',function(self)
  if dragging then self:StopMovingOrSizing();dragging=false;userPositioned=true end
end)
local open=CreateFrame('Button',nil,card,'UIPanelButtonTemplate');open:SetSize(110,23);open:SetPoint('BOTTOMLEFT',card,'BOTTOMLEFT',14,10);open:SetText('Open Farm')
open:SetScript('OnClick',function()if shownID and core.ShowFarmMonster then local id,level=shownID,shownLevel;dismissedID=id;toggled=false;card:Hide();shownID=nil;shownLevel=nil;core.ShowFarmMonster(id,level) end end)
local moveHint=text(137,-335,210)
local close=CreateFrame('Button',nil,card,'UIPanelButtonTemplate');close:SetSize(25,22);close:SetPoint('TOPRIGHT',card,'TOPRIGHT',-9,-15);close:SetText('X')
close:SetScript('OnClick',function()dismissedID=shownID;shownID=nil;toggled=false;card:Hide()end)
local function money(n)
  if type(n)~='number' then return '--' end
  n=math.floor(n+.5);local g=math.floor(n/10000);local s=math.floor(n%10000/100);local c=n%100
  if g>0 then return g..'g '..s..'s '..c..'c' elseif s>0 then return s..'s '..c..'c' end;return c..'c'
end
local function secret(v) return issecretvalue and issecretvalue(v) end
local function mouseoverID()
  if not UnitGUID or not UnitCanAttack then return nil end
  local ok,attack=pcall(UnitCanAttack,'player','mouseover');if not ok or secret(attack) or not attack then return nil end
  local success,guid=pcall(UnitGUID,'mouseover');if not success or secret(guid) or type(guid)~='string' then return nil end
  local kind,id=guid:match('^(%a+)%-[^%-]+%-[^%-]+%-[^%-]+%-[^%-]+%-(%d+)%-')
  if kind~='Creature' then return nil end
  return tonumber(id)
end
local function update()
  if dragging then return end
  if not snapshotActive() then return end
  local id=mouseoverID();if not id or id==dismissedID then return end
  if GameTooltip and GameTooltip.IsShown and not GameTooltip:IsShown() then return end
  local mob=MarketeerForeverFarmData and MarketeerForeverFarmData.mobs[id]
  local okLevel,level=pcall(function()return UnitLevel and UnitLevel('mouseover') end)
  shownLevel=okLevel and not secret(level) and type(level)=='number' and level>=1 and level<=100 and level or nil
  name:SetText(mob and mob.name or 'Creature data unavailable')
  context:SetText(mob and ('Level '..(shownLevel and tostring(shownLevel) or mob.level)..'  |  '..mob.location) or ('No captured loot table for creature #'..id))
  local key=core.Market();local book=key and MarketeerForeverCoreDB and MarketeerForeverCoreDB.prices and MarketeerForeverCoreDB.prices[key]
  local verified=MarketeerForeverMarketActivityMarket and MarketeerForeverMarketActivityMarket()
  local info=verified and MarketeerForeverAPI.GetTableInfo();local normalized=info and type(info.market)=='string' and info.market:lower():gsub('/','.')
  local cache={}
  local function getMarket(itemID)
    if cache[itemID] then return cache[itemID] end
    local row=book and book.items and book.items[itemID]
    local price=type(row)=='table' and not row.carried and type(row.price)=='number' and row.price>0 and row.price or nil
    local a=verified and normalized==verified and MarketeerForeverAPI.GetPrice(itemID)
    local am=a and type(a.market)=='string' and a.market:lower():gsub('/','.')
    cache[itemID]={price=price,sales=a and am==verified and a.soldPerDay or nil};return cache[itemID]
  end
  local result=mob and MarketeerForeverFarmScore.Mob(mob,getMarket,true)
  local skinDrops=MarketeerForeverFarmSkinData and MarketeerForeverFarmSkinData[id]
  local skinResult=MarketeerForeverFarmScore.Skin(skinDrops,getMarket)
  skinLabel:SetShown(skinDrops and #skinDrops>0 or false)
  for i,button in ipairs(skinIcons) do
    local drop=skinDrops and skinDrops[i]
    if drop then
      button.itemID=drop[1]
      local icon=(C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(drop[1])) or (GetItemIcon and GetItemIcon(drop[1]))
      if not icon and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID,drop[1]) end
      button.icon:SetTexture(icon or 134400);button.chance:SetText(string.format('%g%%',drop[2]));button:Show()
    else button.itemID=nil;button:Hide() end
  end
  value:SetText(result and money(result.gross) or '--')
  net:SetText('After 5% AH cut: '..(result and result.gross and money(result.gross*.95) or '--'))
  if skinResult and skinResult.gross then
    local partial=skinResult.partial and ' (partial)' or ''
    skin:SetText('Skinning / successful skin: '..money(skinResult.gross)..partial..(skinResult.classic and ' (Classic data)' or ''))
    local total=result and result.gross and (result.gross+skinResult.gross) or nil
    local incomplete=skinResult.partial or (result and result.priced<#mob.drops)
    combined:SetText('Loot + skin: '..(total and (money(total)..' | after cut '..money(total*.95)) or '--')..(total and incomplete and ' (partial)' or ''))
  elseif skinResult then skin:SetText('Skinning: no scanned prices');combined:SetText('Loot + skin: unavailable')
  else skin:SetText('Skinning: no captured data');combined:SetText('') end
  coverage:SetText(result and ('Priced: '..result.priced..' / '..#mob.drops) or 'No loot data')
  local minutes=book and type(book.observed)=='number' and math.max(0,math.floor(((GetServerTime and GetServerTime() or time())-book.observed)/60))
  age:SetText(minutes and ('Scan: '..minutes..'m ago') or 'No AH scan')
  if result then
    table.sort(result.entries,function(a,b)
      local x,y=a.gross or -1,b.gross or -1;if x~=y then return x>y end
      return (a.drop[2] or 0)>(b.drop[2] or 0)
    end)
  end
  for i,row in ipairs(lines) do
    local e=result and result.entries[i]
    if e then local d=e.drop;row.name:SetText(MarketeerForeverFarmData.items[d[1]] or ('Item #'..d[1]));row.rate:SetText(string.format('%.2f%%',d[2])..(d[5] and '*' or ''));row.price:SetText(money(e.market.price));row.sales:SetText(type(e.market.sales)=='number' and string.format('%.1f',e.market.sales) or '--')
    else row.name:SetText(i==1 and (mob and 'No captured drops' or 'No snapshot available') or '');row.rate:SetText('');row.price:SetText('');row.sales:SetText('') end
  end
  -- Detach from GameTooltip: it moves and is reused after the mouse leaves.
  if not userPositioned then
    card:ClearAllPoints()
    local ok,left,bottom,width,height=pcall(function()if GameTooltip and GameTooltip.GetRect then return GameTooltip:GetRect() end end)
    if ok and type(left)=='number' and type(bottom)=='number' and type(width)=='number' and type(height)=='number' and not secret(left) and not secret(bottom) then
      local ts=GameTooltip.GetEffectiveScale and GameTooltip:GetEffectiveScale() or 1;local us=UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
      local scale=type(ts)=='number' and type(us)=='number' and us>0 and ts/us or 1
      local x,y=left*scale,(bottom+height)*scale
      if x<400 then card:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',x+width*scale+10,y) else card:SetPoint('TOPRIGHT',UIParent,'BOTTOMLEFT',x-10,y) end
    else card:SetPoint('CENTER',UIParent,'CENTER',0,0) end
  end
  local key=modifier();moveHint:SetText(toggleMode() and '|cff91a99aDrag to move|r' or ('|cff91a99a'..(key=='CTRL' and 'Ctrl' or key=='ALT' and 'Alt' or 'Shift')..' + drag to move|r'))
  shownID=id;card:Show()
end
local events=CreateFrame('Frame');events:RegisterEvent('UPDATE_MOUSEOVER_UNIT');events:RegisterEvent('MODIFIER_STATE_CHANGED');events:RegisterEvent('PLAYER_ENTERING_WORLD')
local function hideSnapshot()
  if dragging then card:StopMovingOrSizing();dragging=false;userPositioned=true end
  dismissedID=nil;shownID=nil;card:Hide()
end
function core.ResetFarmHoverState() toggled=false;hideSnapshot() end
events:SetScript('OnEvent',function(_,event,key,down)
  if event=='PLAYER_ENTERING_WORLD' then toggled=false;hideSnapshot();return end
  if event=='MODIFIER_STATE_CHANGED' and toggleMode() then
    local selected=modifier()
    local matches=(selected=='SHIFT' and (key=='LSHIFT' or key=='RSHIFT')) or (selected=='CTRL' and (key=='LCTRL' or key=='RCTRL')) or (selected=='ALT' and (key=='LALT' or key=='RALT'))
    if matches and down==1 and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()) then
      if toggled then toggled=false;hideSnapshot();return end
      if modifierDown() and mouseoverID() then toggled=true;dismissedID=nil;update() end
    end
    return
  end
  if event=='MODIFIER_STATE_CHANGED' and not snapshotActive() then hideSnapshot();return end
  update()
end)
local elapsed=0
events:SetScript('OnUpdate',function(_,dt)
  elapsed=elapsed+dt;if elapsed<.2 then return end;elapsed=0
  if not snapshotActive() then
    if toggleMode() and InCombatLockdown and InCombatLockdown() and (not MarketeerForeverCoreDB or MarketeerForeverCoreDB.farmHoverNoCombat~=false) then toggled=false end
    if card:IsShown() or dragging or dismissedID or shownID then hideSnapshot() end;return
  end
  local id=mouseoverID();local visible=not GameTooltip or not GameTooltip.IsShown or GameTooltip:IsShown()
  if id and visible and id~=dismissedID and (not card:IsShown() or shownID~=id) then update() end
end)
