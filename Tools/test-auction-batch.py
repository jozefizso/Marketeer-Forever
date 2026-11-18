from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'.test-deps'))
from lupa.lua51 import LuaRuntime

source=(Path(__file__).resolve().parents[1]/'MarketeerForever/Trading.lua').read_text(encoding='utf8')
start=source.index('local function nextSelected()')
end=source.index('local function render()',start)
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
owned={{auctionID=10,deposit=100},{auctionID=11},{auctionID=12,deposit=30}}
selectedAuctions={[10]=true,[11]=true}
auctionDeposit=function(a)return a.deposit end
core={active=true};state={ownedComplete=true}
C_AuctionHouse={CancelAuction=function(id)called=id end,CanCancelAuction=function()return true end,IsThrottledMessageSystemReady=function()return true end}
GetServerTime=function()return 100 end;print=function()end
'''+source[start:end]+'''
cancelNext();assert(called==10 and state.cancelPending==10)
called=nil;cancelNext();assert(called==nil)
state.cancelPending=nil;selectedAuctions[10]=nil;cancelNext();assert(called==11 and state.cancelPending==11)
called=nil;state.cancelPending=nil;C_AuctionHouse.CanCancelAuction=function()return false end
cancelNext();assert(called==nil)
''')
print('Each click cancels one selected listing, with pending and eligibility guards.')
tooltip=(Path(__file__).resolve().parents[1]/'MarketeerForever/Tooltip.lua').read_text(encoding='utf8')
part=tooltip[tooltip.index('local function stackCount('):tooltip.index('local function vendorSellValue(')]
lua.execute('''
local function merchantDetails() return nil end
local MarketeerForeverCore={}
'''+part+'''
local owner={marketeerAuctionItemID=42,marketeerAuctionQuantity=7}
local tip={GetOwner=function()return owner end}
local qty,_,_,auction=stackCount(tip,42);assert(qty==7 and auction==true)
assert(stackCount(tip,43)==nil)
''')
lua.execute('assert(loadstring(...))',tooltip)
lua.execute('assert(loadstring(...))',source)
print('Owned auction tooltips use the selected listing quantity.')
part=source[source.index('local function matchedAhead('):source.index('core.MatchedAhead=matchedAhead')]
lua.execute('''
local competitions={};local function keyString(k)return tostring(k.itemID) end
local function auctionValues(a)return a.price end
'''+part+'''
local item={itemKey={itemID=42},auctionID=2,price=100,quantity=5}
local result={complete=true,commodity=true,rows={{price=90,quantity=10},{price=100,quantity=7},{price=100,quantity=3,ownMixed=true,auctionID=1},{price=100,quantity=5,ownMixed=true,auctionID=2},{price=100,quantity=9}}}
competitions['42']=result;assert(matchedAhead(item)==7)
result.rows[4].quantity=4;assert(matchedAhead(item)==nil);result.rows[4].quantity=5
result.rows[2].ownMixed=true;result.rows[2].auctionID=0;assert(matchedAhead(item)==nil)
result.commodity=false;assert(matchedAhead(item)==nil)
''')
print('Matched-ahead counts same-price competitor units and rejects uncertain results.')
start=source.index('local function requestCancellation(id)')
end=source.index('local function cancelNext()',start)
lua.execute('''
local state={};local core={active=true};GetServerTime=function()return 100 end
local blocked=false;local C_AuctionHouse={CancelAuction=function(id) assert(state.cancelPending==id);if blocked then state.cancelPending=nil end end}
'''+source[start:end]+'''
assert(requestCancellation(10) and state.cancelPending==10)
state.cancelPending=nil;blocked=true;assert(not requestCancellation(11) and state.cancelPending==nil)
C_AuctionHouse.CancelAuction=function()error('blocked')end;assert(not requestCancellation(12) and state.cancelPending==nil)
''')
start=source.index('  elseif (event=="ADDON_ACTION_BLOCKED"')
end=source.index('  elseif event=="AUCTION_CANCELED"',start)
branch=source[start:end].replace('  elseif ', '  if ', 1)+'  end\n'
lua.execute('''
local state={cancelPending=10,cancelStarted=100,ownedComplete=true};local renders=0
local render=function()renders=renders+1 end;local event,arg,action='ADDON_ACTION_BLOCKED','OtherAddon','C_AuctionHouse.CancelAuction'
'''+branch+'''
assert(not state.cancelPending and not state.ownedComplete and state.needOwned and renders==1)
''')
print('Cancellation failures clear pending state and preserve the need to refresh.')

start=source.index('  elseif event=="AUCTION_CANCELED" then')
end=source.index('  elseif event=="GET_ITEM_INFO_RECEIVED"',start)
branch=source[start:end].replace('  elseif ', '  if ', 1)+'  end\n'
lua.execute('''
local event,arg='AUCTION_CANCELED',10
local owned={{auctionID=10},{auctionID=11}};local selectedAuctions={[10]=true,[11]=true}
local confirmedCancelled={};local state={cancelPending=10,cancelStarted=100,ownedComplete=true};local expandedAuction;local scrollOffset=0
local render=function()end;local requestOwned=function()end
'''+branch+'''
assert(#owned==1 and owned[1].auctionID==11 and not selectedAuctions[10] and selectedAuctions[11])
assert(confirmedCancelled[10] and not state.cancelPending and state.ownedComplete)
''')
assert 'bulkCancel:SetScript("OnClick",function() cancelNext();render() end)' in source
print('Confirmed cancellation preserves the next selection without a review dialog.')

start=source.index('local function refreshOwned(fromOwnedUpdate)')
end=source.index('local function requestOwned()',start)
lua.execute('''
local owned={{auctionID=10,itemKey={itemID=1}},{auctionID=11,itemKey={itemID=2}}}
local confirmedCancelled={[10]=true};local scrollOffset=0
local selectedAuctions={[11]=true};local function selectedCount()local n=0;for _ in pairs(selectedAuctions) do n=n+1 end;return n end;local state={ownedComplete=true,needOwned=true};local startChecks
local checksAllowed=function()return true end
local core={active=true};local full=false
local render=function()end
C_AuctionHouse={GetNumOwnedAuctions=function()return 1 end,GetOwnedAuctionInfo=function()return {auctionID=10,itemKey={itemID=1}} end,HasFullOwnedAuctionResults=function()return full end}
'''+source[start:end]+'''
refreshOwned(false);assert(#owned==2 and state.ownedComplete and selectedAuctions[11])
full=true;refreshOwned(false);assert(#owned==0 and state.ownedComplete)
''')
print('Partial refresh keeps the confirmed batch snapshot; cancelled IDs stay excluded.')
lua.execute('''
local owned={};local confirmedCancelled={};local scrollOffset=0
local selectedAuctions={};local function selectedCount()return 0 end;local state={ownedComplete=false,needOwned=true,needChecks=true,visitedOwned=false}
local core={active=true};local checks=0;local startChecks=function()checks=checks+1 end
local MarketeerForeverCoreDB={deferListingChecks=true}
local function checksAllowed()return not MarketeerForeverCoreDB.deferListingChecks or state.visitedOwned end
local render=function()end
C_AuctionHouse={GetNumOwnedAuctions=function()return 1 end,GetOwnedAuctionInfo=function()return {auctionID=11,itemKey={itemID=2}} end,HasFullOwnedAuctionResults=function()return true end}
'''+source[start:end]+'''
refreshOwned(false);assert(checks==0 and state.needChecks and state.ownedComplete)
state.visitedOwned=true;refreshOwned(false);assert(checks==1 and not state.needChecks)
state.visitedOwned=false;state.needChecks=true;MarketeerForeverCoreDB.deferListingChecks=false
core.OwnedChecksSettingChanged();assert(checks==2 and not state.needChecks)
''')
print('Listing checks wait for Your Auctions and resume when the setting is disabled.')
