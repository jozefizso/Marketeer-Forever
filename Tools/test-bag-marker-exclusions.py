from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'.test-deps'))
from lupa.lua51 import LuaRuntime
source=(Path(__file__).resolve().parents[1]/'MarketeerForever/BagRules.lua').read_text(encoding='utf8')
match=source[source.index('local function lowestVendorRule()'):source.index('function core.BagRuleValue(item)')]
show=source[source.index('local function showExcludedMarkers()'):source.index('local function paint(button')]
junk=source[source.index('local function junkCandidate('):source.index('local function sellJunk()',source.index('local function junkCandidate('))]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
local shift=false
IsShiftKeyDown=function()return shift end
MarketeerForeverCoreDB={bagValueExclusions={['42']=true}}
local chosen={threshold=1,r=1,g=0,b=0,junk=true,method='auction'}
local function rules()return {chosen}end
local function ruleMethod(r)return r.method end
local function priceFor()return 100 end
local function vendorFor()return 10 end
local function vendorFallbackEligible()return true end
C_Container={GetContainerItemInfo=function()return {itemID=42,stackCount=1}end,GetContainerItemQuestInfo=function()return nil end}
'''+match+show+junk+'''
assert(not matchingRule(42,nil,0,1,showExcludedMarkers()))
shift=true;assert(not matchingRule(42,nil,0,1,showExcludedMarkers()))
MarketeerForeverCoreDB.bagMarkersShowExcludedOnShift=true
assert(matchingRule(42,nil,0,1,showExcludedMarkers())==chosen)
assert(junkCandidate(0,1)==nil)
shift=false;assert(not matchingRule(42,nil,0,1,showExcludedMarkers()))
MarketeerForeverCoreDB.bagValueExclusions['42']=nil
assert(matchingRule(42,nil,0,1,showExcludedMarkers())==chosen and junkCandidate(0,1))
''')
lua.execute('assert(loadstring(...))',source)
lua.execute('assert(loadstring(...))',(Path(__file__).resolve().parents[1]/'MarketeerForever/Menu.lua').read_text(encoding='utf8'))
print('Excluded dots remain hidden by default; Shift override is cosmetic and never enables junk selling.')
