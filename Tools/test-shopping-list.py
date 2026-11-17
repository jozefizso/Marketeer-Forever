from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'.test-deps'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
objects={};local methods={}
function methods:SetScript(k,v)self.scripts[k]=v end
function methods:SetText(v)self.text=v end;function methods:GetText()return self.text or '' end
function methods:GetWidth()return 420 end;function methods:GetFrameLevel()return 1 end;function methods:CreateFontString()return CreateFrame('Font') end
function methods:Hide()self.shown=false end;function methods:Show()self.shown=true end
function methods:IsShown()return self.shown end;function methods:HasFocus()return false end
function methods:ClearFocus()end
local mt={__index=function(_,k)if k=='pooled' or k=='labelIndex' or k=='labels' or k=='buttonIndex' or k=='buttons' or k=='edit' or k=='startCount' then return nil end;return methods[k] or function()end end}
function CreateFrame(kind)local o=setmetatable({kind=kind,scripts={},shown=true},mt);objects[#objects+1]=o;return o end
SlashCmdList={};UIParent=CreateFrame('UI');MarketeerForeverCore={RegisterEscapeFrame=function()error('Shopping list must not close with Escape')end}
GetItemInfo=function(id)return ({[1]='Powder',[2]='Bar'})[id]end
MarketeerForeverCoreDB={prices={test={items={[1]={price=123},[2]={price=200,carried=true}}}}}
MarketeerForeverCore.Market=function()return 'test' end
MarketeerForeverCore.Subscribe=function(fn)scanCallback=fn end
bagItems={};NUM_BAG_SLOTS=4;C_Container={GetContainerNumSlots=function(bag)return bag==0 and #bagItems or 0 end,GetContainerItemInfo=function(_,slot)return bagItems[slot]end}
function fireBags()for _,o in ipairs(objects) do if o.scripts.OnEvent then o.scripts.OnEvent(o,'BAG_UPDATE_DELAYED') end end end
function shownText(value)for _,o in ipairs(objects) do if o.shown and o.text==value then return true end end end
function lastEdit()for i=#objects,1,-1 do if objects[i].kind=='EditBox' and objects[i].shown then return objects[i] end end end
''')
lua.execute((Path(__file__).resolve().parents[1]/'MarketeerForever/ShoppingList.lua').read_text(encoding='utf8'))
lua.execute('''
local c=MarketeerForeverCore
c.AddShoppingRecipe({id=7,name='Solid Shot',materials={{id=1,quantity=1},{id=2,quantity=1}},yieldMin=200})
assert(shownText('Powder') and shownText('Bar') and shownText('0 / 1'))
assert(shownText('AH / UNIT') and shownText('1s 23c') and shownText('--'))
MarketeerForeverCoreDB.prices.test.items[1].price=250;scanCallback('complete');assert(shownText('2s 50c'))
local e=lastEdit();e:SetText('50');e.scripts.OnTextChanged(e,true)
c.AddShoppingRecipe({id=8,name='Other',materials={{id=1,quantity=2}}});assert(shownText('0 / 52') and shownText('0 / 50'))
c.AddShoppingVendor({id=20,name='Vendor Item'});assert(shownText('Vendor Item') and shownText('Needed'))
bagItems={{itemID=1,stackCount=52},{itemID=2,stackCount=20},{itemID=20,stackCount=1}};fireBags()
assert(shownText('|cff73e6a3[OK] 52 / 52|r') and shownText('20 / 50') and shownText('|cff73e6a3[OK]|r'))
bagItems={};fireBags();assert(shownText('0 / 52') and shownText('Needed'))
bagItems={{itemID=2,stackCount=20}}
c.active=true;c.phase='idle';c.CheckBuyout=function(key,callback)callback({tiers={{price=123}}});return true end
C_AuctionHouse={MakeItemKey=function(id)return {itemID=id}end,GetItemKeyInfo=function()return {isCommodity=true}end}
local display={resultsLoaded=false,GetItemID=function()return 2 end,SetQuantitySelected=function(_,q)chosenQuantity=q end}
AuctionHouseFrame={IsShown=function()return true end,CommoditiesBuyFrame={IsShown=function()return true end,BuyDisplay=display},SelectBrowseResult=function(_,result)openedID=result.itemKey.itemID;openedPrice=result.minPrice end,QueryItem=function()end}
AuctionHouseSearchContext={BuyCommodities=1};C_Timer={After=function(_,f)f()end}
fireBags();local open;local count=0
for _,o in ipairs(objects) do if o.shown and o.text=='Open' and o.scripts.OnClick then count=count+1;if count==2 then open=o;break end end end
assert(open);open.scripts.OnClick(open);assert(openedID==2 and openedPrice==123)
for _,o in ipairs(objects) do if o.scripts.OnEvent then o.scripts.OnEvent(o,'COMMODITY_SEARCH_RESULTS_RECEIVED') end;if o.scripts.OnUpdate then o.scripts.OnUpdate(o,.3) end end
assert(chosenQuantity==nil)
display.resultsLoaded=true
for _,o in ipairs(objects) do if o.scripts.OnUpdate then o.scripts.OnUpdate(o,.3) end end
assert(chosenQuantity==30)
chosenQuantity=nil;c.OpenShoppingMaterial(2,3)
for _,o in ipairs(objects) do if o.scripts.OnEvent then o.scripts.OnEvent(o,'COMMODITY_SEARCH_RESULTS_RECEIVED') end end
for _,o in ipairs(objects) do if o.scripts.OnUpdate then o.scripts.OnUpdate(o,.3) end end
assert(chosenQuantity==3)
''')
print('Shopping quantities, bag progress and auction buy-view quantity passed.')
lua.execute('''
MarketeerForeverItemNames={items={[101]='Thorium Bar',[102]='Mithril Bar',[103]='Solid Stone',[104]='Dense Stone',[105]='Wool Cloth',[106]='Bronze Bar',[107]='Heavy Stone',[108]='Runecloth',[109]='Mageweave Cloth',[110]='Steel Bar',[111]='Medium Leather'}}
local text='Wowhead Engineering: Tried & Tested in Forever^"Thorium Bar";;;;;;;;;;;;;177^"Mithril Bar";;;;;;;;;;;;;155^"Solid Stone";;;;;;;;;;;;;140^"Dense Stone";;;;;;;;;;;;;86^"Wool Cloth";;;;;;;;;;;;;60^"Bronze Bar";;;;;;;;;;;;;60^"Heavy Stone";;;;;;;;;;;;;30^"Runecloth";;;;;;;;;;;;;27^"Mageweave Cloth";;;;;;;;;;;;;21^"Steel Bar";;;;;;;;;;;;;16^"Medium Leather";;;;;;;;;;;;;15'
local ok,msg=MarketeerForeverCore.ImportShoppingList(text);assert(ok,msg)
assert(shownText('Wowhead Engineering: Tried & Tested in Forever') and shownText('Thorium Bar') and shownText('0 / 177') and shownText('0 / 15'))
MarketeerForeverCore.AddShoppingRecipe({id=1000,name='Bar recipe',materials={{id=101,name='Thorium Bar',quantity=2}}})
assert(shownText('0 / 179'))
local function removeMaterial(name)
  for _,row in ipairs(objects) do
    local labels=rawget(row,'labels');local buttons=rawget(row,'buttons')
    if row.shown and labels and buttons then
      for _,label in ipairs(labels) do if label.shown and label.text==name then
        for _,b in ipairs(buttons) do if b.shown and b.text=='X' then b.scripts.OnClick(b);return true end end
      end end
    end
  end
end
assert(removeMaterial('Thorium Bar'));assert(shownText('0 / 2') and shownText('0 / 155'))
local invalid=MarketeerForeverCore.ImportShoppingList('Broken^"Thorium Bar";;;;;;;;;;;;;bad');assert(not invalid)
local unmatched=MarketeerForeverCore.ImportShoppingList('Unknown^"Missing Reagent";;;;;;;;;;;;;4');assert(unmatched and shownText('Missing Reagent (unresolved)') and shownText('-- / 4'));assert(removeMaterial('Missing Reagent (unresolved)'));assert(not shownText('Missing Reagent (unresolved)'))
''')
print('Wowhead import, quantities, invalid input, and unmatched items passed.')
