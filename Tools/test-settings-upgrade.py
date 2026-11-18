from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'.test-deps'))
from lupa.lua51 import LuaRuntime

root=Path(__file__).resolve().parents[1]/'MarketeerForever'
lua=LuaRuntime(unpack_returned_tuples=True)
source=(root/'Core.lua').read_text(encoding='utf8')
start=source.index('    showFirstInstallNotice=type(')
end=source.index('  elseif event=="PLAYER_LOGIN"',start)
body=source[start:end]
lua.execute('''
local core={SetAutoScanInterval=function(n) MarketeerForeverCoreDB.scanIntervalMinutes=n end}
local function loadSettings()
'''+body+'''
end
MarketeerForeverCoreDB={autoScan=false,bagCoinEnabled=false,scanIntervalMinutes=45,farmHoverKey='CTRL',farmHoverToggle=true,prices={market={items={[42]={price=123}}}},auctionChatWindows={player={[3]=true}}}
MarketeerForeverMarketDB={markets={realm={watch={[42]=true}}},vendorOffers={offer={price=4}}}
MarketeerForeverCraftDB={crafting={recipes={[12]={name='Example'}}},craftKnownOnly=true}
NokiUnifiedCoreDB={oldToggle=true};NokiUnifiedMarketDB={oldMarket=true};NokiUnifiedCraftDB={oldRecipe=true}
loadSettings();loadSettings()
assert(MarketeerForeverCoreDB.autoScan==false and MarketeerForeverCoreDB.bagCoinEnabled==false and MarketeerForeverCoreDB.scanIntervalMinutes==45)
assert(MarketeerForeverCoreDB.farmHoverKey=='CTRL' and MarketeerForeverCoreDB.farmHoverToggle and MarketeerForeverCoreDB.prices.market.items[42].price==123)
assert(MarketeerForeverCoreDB.auctionChatWindows.player[3] and MarketeerForeverMarketDB.markets.realm.watch[42] and MarketeerForeverMarketDB.vendorOffers.offer.price==4)
assert(MarketeerForeverCraftDB.crafting.recipes[12].name=='Example' and MarketeerForeverCraftDB.craftKnownOnly)
assert(NokiUnifiedCoreDB.oldToggle and NokiUnifiedMarketDB.oldMarket and NokiUnifiedCraftDB.oldRecipe)
MarketeerForeverCoreDB=nil;MarketeerForeverMarketDB=nil;MarketeerForeverCraftDB=nil
loadSettings()
assert(MarketeerForeverCoreDB.oldToggle and MarketeerForeverMarketDB.oldMarket and MarketeerForeverCraftDB.oldRecipe)
assert(NokiUnifiedCoreDB==nil and NokiUnifiedMarketDB==nil and NokiUnifiedCraftDB==nil)
''')

for file,db_name in [('Market/MarketeerForeverMarket.lua','MarketeerForeverMarketDB'),('Crafting/MarketeerForeverCraft.lua','MarketeerForeverCraftDB')]:
    source=(root/file).read_text(encoding='utf8')
    a=source.index('local function initialize()');b=source.index('\nlocal nameQueue',a)
    lua.execute('''
local db,market;local function marketKey()return 'realm' end
'''+source[a:b]+'''
'''+db_name+'''={scanIntervalMinutes=12,autoScan=true,markets={realm={watch={[3]=true},items={}}}}
initialize();assert(db.scanIntervalMinutes==12 and db.autoScan and db.markets.realm.watch[3])
''')
print('Upgrade preserves toggles, hotkeys, markets, recipes, and legacy records.')
