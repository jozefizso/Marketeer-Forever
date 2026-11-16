import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / '.test-deps'))
from lupa.lua51 import LuaRuntime

root = pathlib.Path(__file__).resolve().parents[1] / 'MarketeerForever' / 'Market'
lua = LuaRuntime(unpack_returned_tuples=True)
for name in ('FarmData.lua', 'FarmLookupData.lua', 'FarmScore.lua'):
    lua.execute((root / name).read_text(encoding='utf-8'))
lua.execute('''
local F=MarketeerForeverFarmScore
local d={2589,50,50,100,false}
local gross,fast=F.Drop(d,1000,100)
local _,slow=F.Drop(d,1000,1)
local _,zero=F.Drop(d,1000,0)
local _,missing=F.Drop(d,1000,nil)
local _,small=F.Drop({2589,50,5,10,false},1000,100)
assert(gross==500 and fast>slow and slow>zero and zero==0)
assert(missing==nil and small==nil)
local _,v16=F.Drop(d,1000,16)
local _,v150=F.Drop(d,1000,150)
local _,v300=F.Drop(d,1000,300)
local _,v1000=F.Drop(d,1000,1000)
assert(math.abs(v16/v300-16/300)<0.000001 and math.abs(v150/v300-0.5)<0.000001 and v1000==v300)
local grossMismatch,scoreMismatch=F.Drop({1,0.03,1,27,false},149900,14.5)
assert(grossMismatch<45 and scoreMismatch>=0 and scoreMismatch<=grossMismatch)
local m=F.Mob({drops={d,{1,10,1,10,false}}},function(id) if id==2589 then return {price=1000,sales=100} end end,true)
assert(m.gross==500 and m.scored==1 and m.missingPrice==1 and #m.entries==2)
local count=0;for _,v in pairs(MarketeerForeverFarmData.mobs) do assert(v.min>0 and v.max>=v.min and #v.drops>0);count=count+1 end
assert(count>1000)
local linen=MarketeerForeverFarmLookup.items[2589];assert(linen and #linen.drops>200)
local ore=MarketeerForeverFarmLookup.items[3340];assert(ore and ore.name=='Incendicite Ore' and #ore.drops==0 and #ore.sources==2 and ore.sources[1][1]=='Incendicite Mineral Vein' and ore.sources[1][3]=='Wetlands' and ore.sources[1][4]==100)
local saw=false;for _,d in ipairs(linen.drops) do if d[1]==481 then saw=true;assert(MarketeerForeverFarmLookup.npcs[d[1]][1]=='Defias Footpad') end end;assert(saw)
''')
lua.execute('''
local objects={}
local methods={}
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:SetPoint(...) self.point={...} end
function methods:RegisterEvent() end
function methods:Hide() self.shown=false end
function methods:Show() self.shown=true;if self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown end
function methods:SetText(t) self.text=t end
function methods:SetMaxLetters(n) if n==100 then if not lookupInput then lookupInput=self else recipeInput=self end elseif n==3 then levelInput=self elseif n==60 and not farmSearch then farmSearch=self end end
function methods:GetText() return rawget(self,'text') or '' end
function methods:GetWidth() return 900 end
function methods:GetHeight() return 500 end
function methods:GetFrameLevel() return 1 end
function methods:CreateFontString() local f=CreateFrame();f.parent=self;return f end
function methods:CreateTexture() return CreateFrame() end
function methods:ClearFocus() end
function methods:StartMoving() self.moving=true end
function methods:StopMovingOrSizing() self.moving=false end
local mt={__index=function(_,k) return methods[k] or function() end end}
function CreateFrame() local x=setmetatable({scripts={},shown=false},mt);objects[#objects+1]=x;if captureNextFrame then hoverCard=x;captureNextFrame=false end;return x end
AuctionHouseFrame=CreateFrame()
UIParent=CreateFrame(); Minimap=CreateFrame(); SlashCmdList={}
ContainerFrameItemButtonMixin={OnClick=function() nativeClicks=nativeClicks+1 end}
nativeClicks=0;IsAltKeyDown=function()return true end;IsShiftKeyDown=function()return false end;IsControlKeyDown=function()return false end;InCombatLockdown=function()return false end
clickedItem=2589;C_Container={GetContainerItemInfo=function()return {itemID=clickedItem}end}
function hooksecurefunc(object,name,callback) if type(object)=='table' then local original=object[name];object[name]=function(...) original(...);callback(...) end end end
UnitLevel=function() return 60 end
GetServerTime=function() return 10000 end
MarketeerForeverCore={Market=function() return 'forever/pvp/horde/us' end,Subscribe=function(f) end,RegisterEscapeFrame=function()end,CreateHistoryPanel=function() local h=CreateFrame();h.Refresh=function()end;h.SetItem=function()end;return h end}
MarketeerForeverCoreDB={prices={['forever/pvp/horde/us']={observed=9900,items={[2589]={price=100}}}}}
MarketeerForeverMarketActivityMarket=function() return 'forever.pvp.horde.us' end
MarketeerForeverAPI={GetTableInfo=function()return {market='forever/pvp/horde/us'} end,GetPrice=function()return {market='forever/pvp/horde/us',soldPerDay=50}end}
MarketeerForeverTabs={CreateTab=function(self,id,panel) self.id=id;self.panel=panel end}
C_Timer={After=function(_,fn)fn()end}
GameTooltip={SetOwner=function()end,AddLine=function(_,s) if type(s)=='string' then tooltipLines=tooltipLines..s..' ' end end,Show=function()end,Hide=function()end,IsShown=function()return true end,GetCenter=function()return 500,200 end}
function hasText(s) for _,o in ipairs(objects) do local t=rawget(o,'text');if type(t)=='string' and t:find(s,1,true) then return true end end;return false end
function hoverAligned(header,value) local a,b;for _,o in ipairs(objects) do if rawget(o,'parent')==hoverCard then if rawget(o,'text')==header then a=o.point[4] elseif rawget(o,'text')==value then b=o.point[4] end end end;return a~=nil and a==b end
function clickLabel(s) for _,o in ipairs(objects) do if rawget(o,'text')==s and o.scripts.OnClick then o.scripts.OnClick(o);return true end end;return false end
function clickButtonText(s) for _,o in ipairs(objects) do if rawget(o,'text')==s and rawget(o,'parent') and o.parent.scripts.OnClick then o.parent.scripts.OnClick(o.parent);return true end end end
function checkTooltips() tooltipLines='';for _,o in ipairs(objects) do if o.scripts.OnEnter then pcall(o.scripts.OnEnter,o) end end;assert(tooltipLines:find('Monster score',1,true) and tooltipLines:find('Score coverage',1,true) and tooltipLines:find('Drop score contribution',1,true)) end
function tickHover() for _,o in ipairs(objects) do if o.scripts.OnUpdate then o.scripts.OnUpdate(o,.25) end end end
''')
lua.execute((root / 'Farm.lua').read_text(encoding='utf-8'))
lua.execute((root / 'FarmLookup.lua').read_text(encoding='utf-8'))
lua.execute("shiftDown=false;IsShiftKeyDown=function()return shiftDown end;UnitCanAttack=function()return true end;UnitGUID=function()return 'Creature-0-0-0-0-481-12345' end;captureNextFrame=true")
lua.execute((root / 'FarmHover.lua').read_text(encoding='utf-8'))
lua.execute("shiftDown=true;tickHover();assert(hoverCard:IsShown() and hasText('Defias Footpad') and hasText('After 5% AH cut') and hoverAligned('AH PRICE','1s 0c'));UnitCanAttack=function()return false end;tickHover();assert(hoverCard:IsShown());hoverCard.scripts.OnDragStart(hoverCard);assert(hoverCard.moving);hoverCard.scripts.OnDragStop(hoverCard);assert(not hoverCard.moving);MarketeerForeverCore.ShowFarmMonster=function(id,level) openedMob=id;openedLevel=level end;assert(clickLabel('Open Farm') and openedMob==481 and openedLevel==60 and not hoverCard:IsShown());shiftDown=false;tickHover();UnitCanAttack=function()return true end;shiftDown=true;tickHover();assert(hoverCard:IsShown());shiftDown=false;tickHover();assert(not hoverCard:IsShown());IsShiftKeyDown=function()return false end")
lua.execute((root.parent / 'Crafting' / 'CraftingCatalog.lua').read_text(encoding='utf-8'))
lua.execute((root.parent / 'Crafting' / 'RecipeBrowser.lua').read_text(encoding='utf-8'))
lua.execute('''
assert(MarketeerForeverCore.HasItemRecipe(279981))
local recipe={output=2,yieldMin=2,yieldMax=3,materials={{id=1,quantity=4}}}
local book={items={[1]={price=10},[2]={price=100,quantity=7}}}
local x=MarketeerForeverCore.RecipeEstimate(recipe,book,{soldPerDay=350})
assert(x.cost==40 and x.sale==100 and x.gainMin==150 and x.gainMax==245 and x.sales==350 and x.listed==7)
book.items[1]=nil;x=MarketeerForeverCore.RecipeEstimate(recipe,book,nil);assert(x.cost==nil and x.gainMin==nil and x.missing==1)
recipe.yieldMin=nil;x=MarketeerForeverCore.RecipeEstimate(recipe,{items={[1]={price=10},[2]={price=100}}},nil);assert(x.gainMin==nil)
''')
lua.execute((root.parent / 'Menu.lua').read_text(encoding='utf-8'))
lua.execute("MarketeerForeverCore.FarmHasSpawnReferences=function(id)return id==481 end")
lua.execute("MarketeerForeverCore.OpenTradingMenu('farm');assert(MarketeerForeverTabs.id==nil and levelInput:GetText()=='');checkTooltips();farmSearch:SetText('Defias Footpad');levelInput:SetText('1');levelInput.scripts.OnEnterPressed(levelInput);assert(hasText('No results with the current filters'));levelInput:SetText('');levelInput.scripts.OnEnterPressed(levelInput);assert(not hasText('No results with the current filters'));farmSearch:SetText('');MarketeerForeverCore.ShowItemDrops(2589);assert(hasText('Linen Cloth') and hasText('Tamara Armstrong'));MarketeerForeverCore.ShowFarmMonster(481,10);assert(hasText('Defias Footpad') and farmSearch:GetText()=='Defias Footpad' and levelInput:GetText()=='10');MarketeerForeverCore.ShowItemDrops(3340);assert(lookupInput:GetText()=='Incendicite Ore' and hasText('Incendicite Mineral Vein') and hasText('Mined from'));MarketeerForeverCore.OpenTradingMenu('history');MarketeerForeverCore.OpenTradingMenu('bag');ContainerFrameItemButtonMixin.OnClick({GetBagID=function()return 0 end,GetID=function()return 1 end},'RightButton');assert(nativeClicks==1 and lookupInput:GetText()=='Linen Cloth');clickedItem=279981;ContainerFrameItemButtonMixin.OnClick({GetBagID=function()return 0 end,GetID=function()return 1 end},'RightButton');assert(nativeClicks==2 and recipeInput:GetText()~='' and hasText('Basic Campfire'))")
lua.execute("MarketeerForeverCore.ShowFarmMonster(481,10);local f=MarketeerForeverCore.CreateFarmPanel(UIParent);assert(f:IsShown() and hasText('Defias Footpad | Level') and hasText('|A:Waypoint-MapPin-Untracked:14:14|a Defias Footpad') and hasText('Classic spawn data'));f:Hide();MarketeerForeverCore.OpenTradingMenu();assert(f:IsShown() and farmSearch:GetText()=='Defias Footpad' and levelInput:GetText()=='10' and hasText('Defias Footpad | Level'))")
lua.execute("MarketeerForeverCore.ShowAuctionChatSettings=function()chatSettingsOpened=true end;MarketeerForeverCore.OpenTradingMenu('auctionchat');assert(hasText('CHATTYNATOR IS OPTIONAL') and hasText('standard WoW chat window'));assert(clickButtonText('Assign Chattynator tabs') and chatSettingsOpened)")
lua.execute("MarketeerForeverCore.OpenTradingMenu('hotkeys');assert(hasText('MONSTER HOVER SNAPSHOT') and hasText('Current: Shift'));assert(clickButtonText('Ctrl') and MarketeerForeverCoreDB.farmHoverKey=='CTRL' and hasText('Current: Ctrl'));ctrlDown=false;IsControlKeyDown=function()return ctrlDown end;IsShiftKeyDown=function()return true end;tickHover();assert(not hoverCard:IsShown());ctrlDown=true;tickHover();assert(hoverCard:IsShown() and hasText('Ctrl + drag to move'));MarketeerForeverCoreDB.farmHoverNoCombat=true;InCombatLockdown=function()return true end;tickHover();assert(not hoverCard:IsShown());InCombatLockdown=function()return false end;tickHover();assert(hoverCard:IsShown());assert(clickButtonText('Off'));tickHover();assert(not hoverCard:IsShown())")
print('Volume scoring, Linen Cloth lookup and widget navigation passed without the auction house.')
