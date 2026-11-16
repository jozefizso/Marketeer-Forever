from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'.test-deps'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
objects={};local methods={}
function methods:SetScript(k,v)self.scripts[k]=v end
function methods:SetText(v)self.text=v end;function methods:GetText()return self.text or '' end
function methods:GetWidth()return 420 end;function methods:CreateFontString()return CreateFrame('Font') end
function methods:Hide()self.shown=false end;function methods:Show()self.shown=true end
function methods:IsShown()return self.shown end;function methods:HasFocus()return false end
function methods:ClearFocus()end
local mt={__index=function(_,k)if k=='pooled' or k=='labelIndex' or k=='labels' or k=='buttonIndex' or k=='buttons' or k=='edit' or k=='startCount' then return nil end;return methods[k] or function()end end}
function CreateFrame(kind)local o=setmetatable({kind=kind,scripts={},shown=true},mt);objects[#objects+1]=o;return o end
UIParent=CreateFrame('UI');MarketeerForeverCore={RegisterEscapeFrame=function()error('Shopping list must not close with Escape')end}
GetItemInfo=function(id)return ({[1]='Powder',[2]='Bar'})[id]end
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
local e=lastEdit();e:SetText('50');e.scripts.OnTextChanged(e,true)
c.AddShoppingRecipe({id=8,name='Other',materials={{id=1,quantity=2}}});assert(shownText('0 / 52') and shownText('0 / 50'))
c.AddShoppingVendor({id=20,name='Vendor Item'});assert(shownText('Vendor Item') and shownText('Needed'))
bagItems={{itemID=1,stackCount=52},{itemID=2,stackCount=20},{itemID=20,stackCount=1}};fireBags()
assert(shownText('|cff73e6a3[OK] 52 / 52|r') and shownText('20 / 50') and shownText('|cff73e6a3[OK]|r'))
bagItems={};fireBags();assert(shownText('0 / 52') and shownText('Needed'))
''')
print('Craft-count multiplication, shared materials and vendor items passed.')
