from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / '.test-deps'))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
MarketeerForeverCore={Market=function()return 'test' end}
MarketeerForeverCoreDB={prices={test={observed=1000,items={[42]={price=5,observed=1000,quantity=10}}}}}
MarketeerForeverMarketVendorData={{42,'Item','Vendor',900,200}}
MarketeerForeverAPI={GetPrice=function()return {soldPerDay=30}end,GetTableInfo=function()return {updated=1000}end,GetTrend=function()end}
GetServerTime=function()return 1060 end;IsShiftKeyDown=function()return true end
GameTooltip={lines={},GetItem=function()return 'Item','item:42' end,GetOwner=function()return {marketeerAuctionItemID=42,marketeerAuctionQuantity=200}end,
 AddDoubleLine=function(self,a,b)self.lines[#self.lines+1]={a,b}end,AddLine=function(self,a)self.lines[#self.lines+1]={a}end,Show=function()end}
TooltipDataProcessor={AddTooltipPostCall=function(_,fn)callback=fn end};Enum={TooltipDataType={Item=1}}
eventFrames={}
CreateFrame=function()return {RegisterEvent=function(self,event)eventFrames[event]=self end,SetScript=function(self,_,fn)self.handler=fn end}end
''')
source=(Path(__file__).resolve().parents[1] / 'MarketeerForever/Tooltip.lua').read_text(encoding='utf-8-sig')
lua.execute(source)
lua.execute('''
local selected,owner={id=42,recipe={yieldMin=200}},{}
GameTooltip.SetOwner=function(self,o)self.owner=o end;GameTooltip.GetOwner=function(self)return self.owner end
GameTooltip.SetHyperlink=function(self,link)self.link=link end;GameTooltip.Hide=function(self)self.hidden=true end
MarketeerForeverCore.ShowResultItemTooltip(owner,selected);assert(GameTooltip.link=='item:42' and owner.marketeerResultQuantity==200)
assert(MarketeerForeverCore.ItemStackContext(GameTooltip,42)==200)
MarketeerForeverCore.HideResultItemTooltip(owner);assert(GameTooltip.hidden and owner.marketeerResultItemID==nil)
selected={id=42,stack=50};MarketeerForeverCore.ShowResultItemTooltip(owner,selected);assert(owner.marketeerResultQuantity==50)
-- Avoid creating the separate trend frame; the layout under test is the item tooltip.
GameTooltip=nil
local t={lines={},GetItem=function()return 'Item','item:42' end,GetOwner=function()return {marketeerAuctionItemID=42,marketeerAuctionQuantity=200}end,
 AddDoubleLine=function(self,a,b)self.lines[#self.lines+1]={a,b}end,AddLine=function(self,a)self.lines[#self.lines+1]={a}end,Show=function()end}
callback(t,{id=42});local joined='';local vendor
for _,line in ipairs(t.lines) do joined=joined..line[1]..' '..(line[2] or '')..' ';if line[1]:find('Vendor buy / unit / stack',1,true) then vendor=line[2] end end
assert(vendor and vendor:find('4.5',1,true) and vendor:find('9|TInterface',1,true))
assert(joined:find('Scan: 1m ago',1,true));assert(not joined:find('Est. sales / day',1,true))
assert(joined:find('AH / unit',1,true) and joined:find('AH stack price (200)',1,true))
IsShiftKeyDown=function()return false end;t.lines={};callback(t,{id=42})
local prices={};for _,line in ipairs(t.lines) do prices[line[1]]=line[2] end
assert(prices['AH / unit'] and prices['AH stack price (200)'])
assert(prices['AH / unit']:find('5',1,true) and prices['AH stack price (200)']:find('10',1,true))
IsShiftKeyDown=function()return true end
assert(not joined:find('Recorded sources',1,true) and not joined:find('Alt+',1,true) and not joined:find('Prices from AHledger',1,true))
''')
lua.execute('''
local estimate=MarketeerForeverCore.TooltipProfitEstimate
MarketeerForeverCore.OwnedVendorCost=function()return {cost=900,pack=200}end
local r=estimate(42,200,nil,nil,5);assert(r.cost==900 and r.lowProfit==50 and r.profitableUnit==5 and r.profitableProfit==50)
r=estimate(42,200,1200,nil,5);assert(r.lowProfit==-250 and r.profitableUnit==7 and r.profitableProfit==130)
MarketeerForeverCraftCraftCatalog={recipes={{output=42,yieldMin=10,materials={{id=99,quantity=2}},name='Test craft'}}}
local book={items={[99]={price=20}}};r=estimate(42,21,nil,book,50);assert(r.craft==120 and r.cost==120 and r.basis=='Craft estimate' and r.crafts==3)
book.items[99].carried=true;r=estimate(42,21,nil,book,50);assert(r.craft==nil and r.cost==900)
MarketeerForeverCore.OwnedVendorCost=nil;MarketeerForeverCraftCraftCatalog=nil;r=estimate(42,nil,nil,nil,5);assert(r.quantity==1 and r.cost==nil and r.profitableUnit==nil)
''')
lua.execute('''
local texts={};local methods={}
function methods:SetText(s)texts[#texts+1]=s end
function methods:CreateFontString()return setmetatable({}, {__index=methods}) end
function methods:CreateTexture()return setmetatable({}, {__index=methods}) end
function methods:SetScript(name,fn)local scripts=rawget(self,'scripts') or {};self.scripts=scripts;scripts[name]=fn end
function methods:Show()self.shown=true end
function methods:Hide()self.shown=false end
function methods:IsShown()return self.shown==true end
setmetatable(methods,{__index=function()return function()end end})
local uiFrames={}
CreateFrame=function()local frame=setmetatable({}, {__index=methods});uiFrames[#uiFrames+1]=frame;return frame end
UIParent=CreateFrame();GameTooltip={lines={},GetItem=function()return 'Item','item:42' end,GetOwner=function()return {marketeerAuctionItemID=42,marketeerAuctionQuantity=200}end,
 AddDoubleLine=function(self,a,b)self.lines[#self.lines+1]={a,b}end,AddLine=function(self,a)self.lines[#self.lines+1]={a}end,Show=function()end}
MarketeerForeverCore.OwnedVendorCost=function()return {cost=900}end
callback(GameTooltip,{id=42})
local all=table.concat(texts,'|');assert(not all:find('MARKET  |  PROFIT & LOSS',1,true));assert(all:find('Profit after AH cut',1,true));assert(all:find('First profitable / unit',1,true));assert(all:find('24 hours',1,true));assert(all:find('Demand gap||cff71e4a2+20|r',1,true))
assert(all:find('LAST AH SCAN',1,true) and all:find('VENDOR FLIP ON AH',1,true) and all:find('|cff71e4a2PROFITABLE|r',1,true));assert(not all:find('LAST CRAFT',1,true))
assert(all:find('LAST AH SCAN  |  1 mins ago',1,true) and not all:find('AH low / unit (1m)',1,true))
GetRealmName=function()return 'Realm' end;UnitName=function()return 'Player' end
MarketeerForeverCraftDB={crafting={['Realm|Player']={Cooking={recipes={[1]={name='Fish feast'}}},Alchemy={recipes={[2]={name='Elixir'},[3]={name='Other'}}}},['Realm|Other']={Cooking={recipes={[4]={name='Not mine'}}}}}}
MarketeerForeverCraftCraftCatalog={recipes={[1]={name='Fish feast',materials={{id=42}}},[2]={name='Elixir',materials={{id=42}}},[3]={name='Other',materials={{id=99}}},[4]={name='Not mine',materials={{id=42}}},[5]={name='Unknown',materials={{id=42}}}}}
local known=MarketeerForeverCore.KnownResourceRecipes(42);assert(#known==2 and known[1].profession=='Alchemy' and known[2].profession=='Cooking')
local calc=MarketeerForeverCore.RecipeMarketEstimate
local recipe={output=50,yieldMin=2,materials={{id=42,quantity=3},{id=43,quantity=1}}}
local prices={items={[42]={price=5},[43]={price=10},[50]={price=30,quantity=20}}}
local result=calc(recipe,prices);assert(result.cost==25 and result.profit==32 and result.price==30 and result.yield==2 and result.sales==30 and result.gap==10)
prices.items[43].carried=true;result=calc(recipe,prices);assert(result.cost==nil and result.profit==nil and result.sales==30)
prices.items[43].carried=nil;recipe.review=true;result=calc(recipe,prices);assert(result.cost==nil and result.profit==nil)
texts={};callback(GameTooltip,{id=42});all=table.concat(texts,'|');assert(all:find('KNOWN RECIPES',1,true) and all:find('Elixir',1,true) and all:find('Fish feast',1,true) and not all:find('Not mine',1,true))
assert(all:find('Cost / craft:',1,true) and all:find('Profit after 5%:',1,true) and all:find('AH low / unit:',1,true) and all:find('Est. sales / day:',1,true) and all:find('Gap:',1,true))
MarketeerForeverCraftCraftCatalog.recipes[6]={output=42,yieldMin=200,name='Batch craft',materials={{id=43,quantity=200}}}
MarketeerForeverCoreDB.prices.test.items[43]={price=2};texts={};callback(GameTooltip,{id=42});all=table.concat(texts,'|')
assert(all:find('Craft cost for 1|2',1,true) and all:find('Profit ea AH match||cff71e4a2+2.75',1,true))
assert(all:find('Lowest profitable unit price',1,true) and all:find('P/L at lowest possible (200)',1,true) and all:find('P/L at lowest possible (1)',1,true))
texts={};MarketeerForeverCore.OwnedVendorCost=function()return {cost=1200}end
MarketeerForeverCoreDB.prices.test.items[42].quantity=40;callback(GameTooltip,{id=42})
all=table.concat(texts,'|');assert(all:find('Demand gap||cffff6666-10|r',1,true));assert(all:find('|cffff7777LOSS|r',1,true))
texts={};MarketeerForeverCoreDB.prices.test.items[42].price=nil;callback(GameTooltip,{id=42})
all=table.concat(texts,'|');assert(all:find('|cffbdbdbdNO SCAN|r',1,true))
local down,clock=false,0;IsShiftKeyDown=function()return down end;GetTime=function()return clock end
local bagOwner={GetBagID=function()return 0 end,GetID=function()return 2 end}
C_Container={GetContainerItemInfo=function()return {itemID=42,stackCount=200}end}
GameTooltip.GetOwner=function()return bagOwner end;GameTooltip.IsShown=function()return true end
GameTooltip.RefreshData=function()callback(GameTooltip,{id=42})end
local event=eventFrames.MODIFIER_STATE_CHANGED
local marketPanel,knownPanel
for _,frame in ipairs(uiFrames) do if rawget(frame,'rows') and rawget(frame,'headings') then marketPanel=frame elseif rawget(frame,'entries') and rawget(frame,'lines') then knownPanel=frame end end
assert(marketPanel and knownPanel)
marketPanel.dragging=false
marketPanel.GetLeft=function()return 100 end;marketPanel.GetTop=function()return 500 end;marketPanel.GetEffectiveScale=function()return 1 end
UIParent.GetEffectiveScale=function()return 1 end
marketPanel.SetPoint=function(self,point,relative,relativePoint,x,y)self.anchor={point,relative,relativePoint,x,y}end
down=true;event.handler(event,'MODIFIER_STATE_CHANGED','LSHIFT',1);assert(not MarketeerForeverCore.IsMarketDetailsPinned())
down=false;event.handler(event,'MODIFIER_STATE_CHANGED','LSHIFT',0)
clock=.3;down=true;event.handler(event,'MODIFIER_STATE_CHANGED','LSHIFT',1);assert(MarketeerForeverCore.IsMarketDetailsPinned())
assert(marketPanel.anchor[2]==UIParent and marketPanel.anchor[4]==100 and marketPanel.anchor[5]==500)
marketPanel.scripts.OnDragStart();assert(marketPanel.dragging);marketPanel.scripts.OnDragStop();assert(not marketPanel.dragging)
knownPanel.entries={};for i=1,24 do knownPanel.entries[i]={'test'} end;knownPanel.offset=0
knownPanel.scripts.OnMouseWheel(knownPanel,-1);assert(knownPanel.offset==3)
down=false;event.handler(event,'MODIFIER_STATE_CHANGED','LSHIFT',0);assert(MarketeerForeverCore.IsMarketDetailsPinned())
down=true;event.handler(event,'MODIFIER_STATE_CHANGED','LSHIFT',1);assert(not MarketeerForeverCore.IsMarketDetailsPinned())
''')
print('Compact tooltip and vendor, crafting, loss, and profitable-price estimates passed.')
