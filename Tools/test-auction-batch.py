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
selectedAuctions={[10]=true,[11]=true};approvedBatch=true
auctionDeposit=function(a)return a.deposit end
core={active=true};state={ownedComplete=true}
C_AuctionHouse={CancelAuction=function(id)called=id end,CanCancelAuction=function()return true end,IsThrottledMessageSystemReady=function()return true end}
GetServerTime=function()return 100 end;print=function()end
'''+source[start:end]+'''
local total,unknown,count,ids=selectedDeposits()
assert(total==100 and unknown==1 and count==2 and ids=='10,11')
cancelNext();assert(called==10 and state.cancelPending==10)
called=nil;cancelNext();assert(called==nil)
state.cancelPending=nil;selectedAuctions[10]=nil;C_AuctionHouse.CanCancelAuction=function()return false end
cancelNext();assert(called==nil and not approvedBatch)
''')
print('Batch deposit totals and cancellation guards passed.')
start=source.index('local function requestCancellation(id)')
end=source.index('local function cancelNext()',start)
lua.execute('''
local state={};local approvedBatch=true;local core={active=true};GetServerTime=function()return 100 end
local blocked=false;local C_AuctionHouse={CancelAuction=function(id) assert(state.cancelPending==id);if blocked then state.cancelPending=nil;approvedBatch=false end end}
'''+source[start:end]+'''
assert(requestCancellation(10) and state.cancelPending==10)
state.cancelPending=nil;blocked=true;assert(not requestCancellation(11) and state.cancelPending==nil and not approvedBatch)
C_AuctionHouse.CancelAuction=function()error('blocked')end;assert(not requestCancellation(12) and state.cancelPending==nil)
''')
start=source.index('  elseif (event=="ADDON_ACTION_BLOCKED"')
end=source.index('  elseif event=="AUCTION_CANCELED"',start)
branch=source[start:end].replace('  elseif ', '  if ', 1)+'  end\n'
lua.execute('''
local state={cancelPending=10,cancelStarted=100,ownedComplete=true};local approvedBatch=true;local renders=0
local render=function()renders=renders+1 end;local event,arg,action='ADDON_ACTION_BLOCKED','OtherAddon','C_AuctionHouse.CancelAuction'
'''+branch+'''
assert(not state.cancelPending and not state.ownedComplete and state.needOwned and not approvedBatch and renders==1)
''')
print('Cancellation failures clear pending state and preserve the need to refresh.')
start=source.index('local function refreshOwned(fromOwnedUpdate)')
end=source.index('local function requestOwned()',start)
lua.execute('''
local owned={{auctionID=10,itemKey={itemID=1}},{auctionID=11,itemKey={itemID=2}}}
local confirmedCancelled={[10]=true};local approvedBatch=true;local scrollOffset=0
local selectedAuctions={[11]=true};local state={ownedComplete=true,needOwned=true};local startChecks
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
local owned={};local confirmedCancelled={};local approvedBatch=false;local scrollOffset=0
local selectedAuctions={};local state={ownedComplete=false,needOwned=true,needChecks=true,visitedOwned=false}
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
