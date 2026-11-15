-- A small pinned creature card; mouse interaction is confined to this frame.
local core=MarketeerForeverCore
local card=CreateFrame('Frame',nil,UIParent,'BackdropTemplate')
card:SetSize(390,266);card:SetFrameStrata('TOOLTIP');card:SetClampedToScreen(true);card:EnableMouse(true);card:SetMovable(true);card:RegisterForDrag('LeftButton')
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
local divider=card:CreateTexture(nil,'ARTWORK');divider:SetColorTexture(.22,.35,.25,1);divider:SetPoint('TOPLEFT',card,'TOPLEFT',14,-135);divider:SetPoint('TOPRIGHT',card,'TOPRIGHT',-14,-135);divider:SetHeight(1)
local columns={{key='name',title='DROP',x=14,width=160},{key='rate',title='CHANCE',x=178,width=54},{key='price',title='AH PRICE',x=235,width=73},{key='sales',title='SALES/D',x=312,width=64}}
for _,col in ipairs(columns) do text(col.x,-143,col.width,'GameFontNormalSmall'):SetText(col.title) end
local lines={};for i=1,3 do local row={};for _,col in ipairs(columns) do row[col.key]=text(col.x,-160-(i-1)*17,col.width) end;lines[i]=row end
local note=text(14,-218,315);note:SetText('|cff91a99a1 per drop; assumes sales. No deposit costs.|r')
local shownID,shownLevel,dismissedID,dragging,userPositioned
card:SetScript('OnDragStart',function(self)
  if IsShiftKeyDown and IsShiftKeyDown() then dragging=true;self:StartMoving() end
end)
card:SetScript('OnDragStop',function(self)
  if dragging then self:StopMovingOrSizing();dragging=false;userPositioned=true end
end)
local open=CreateFrame('Button',nil,card,'UIPanelButtonTemplate');open:SetSize(110,23);open:SetPoint('BOTTOMLEFT',card,'BOTTOMLEFT',14,10);open:SetText('Open Farm')
open:SetScript('OnClick',function()if shownID and core.ShowFarmMonster then local id,level=shownID,shownLevel;dismissedID=id;card:Hide();shownID=nil;shownLevel=nil;core.ShowFarmMonster(id,level) end end)
local moveHint=text(137,-242,180);moveHint:SetText('|cff91a99aShift + drag to move|r')
local close=CreateFrame('Button',nil,card,'UIPanelButtonTemplate');close:SetSize(25,22);close:SetPoint('TOPRIGHT',card,'TOPRIGHT',-9,-15);close:SetText('X')
close:SetScript('OnClick',function()dismissedID=shownID;shownID=nil;card:Hide()end)
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
  if not IsShiftKeyDown or not IsShiftKeyDown() then return end
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
  value:SetText(result and money(result.gross) or '--')
  net:SetText('After 5% AH cut: '..(result and result.gross and money(result.gross*.95) or '--'))
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
  shownID=id;card:Show()
end
local events=CreateFrame('Frame');events:RegisterEvent('UPDATE_MOUSEOVER_UNIT');events:RegisterEvent('MODIFIER_STATE_CHANGED');events:RegisterEvent('PLAYER_ENTERING_WORLD')
events:SetScript('OnEvent',function(_,event,key)
  if event=='MODIFIER_STATE_CHANGED' and key~='LSHIFT' and key~='RSHIFT' then return end
  if event=='MODIFIER_STATE_CHANGED' and (not IsShiftKeyDown or not IsShiftKeyDown()) then
    if dragging then card:StopMovingOrSizing();dragging=false;userPositioned=true end
    dismissedID=nil;shownID=nil;card:Hide();return
  end
  update()
end)
local elapsed=0
events:SetScript('OnUpdate',function(_,dt)
  elapsed=elapsed+dt;if elapsed<.2 then return end;elapsed=0
  if not IsShiftKeyDown or not IsShiftKeyDown() then
    if dragging then card:StopMovingOrSizing();dragging=false;userPositioned=true end
    dismissedID=nil;shownID=nil;if card:IsShown() then card:Hide() end;return
  end
  local id=mouseoverID();local visible=not GameTooltip or not GameTooltip.IsShown or GameTooltip:IsShown()
  if id and visible and id~=dismissedID and (not card:IsShown() or shownID~=id) then update() end
end)
