from pathlib import Path
import re,sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'.test-deps'))
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]/'MarketeerForever'
lua=LuaRuntime(unpack_returned_tuples=True)
for relative in ('Market/FlipPanel.lua','Crafting/FlipPanel.lua'):
 s=(root/relative).read_text(encoding='utf8');lua.execute('assert(loadstring(...))',s)
 start=s.index('  local function layoutRows()');end=s.index('  panel:SetScript("OnSizeChanged",layoutRows)',start)
 layout=s[start:end]
 lua.execute('''
 local MAX_ROWS,ROWS_PER_PAGE=16,7;local h=0;local renders=0
 local panel={GetHeight=function()return h end};local function render()renders=renders+1 end
 '''+layout+'''
 h=500;layoutRows();assert(ROWS_PER_PAGE==8 and renders==1)
 h=602;layoutRows();assert(ROWS_PER_PAGE==11 and renders==2)
 h=1200;layoutRows();assert(ROWS_PER_PAGE==16)
 h=500;layoutRows();assert(ROWS_PER_PAGE==8)
 ''')
 assert 'local item = i<=ROWS_PER_PAGE and filtered[scrollOffset + i] or nil' in s
 assert 'pageText:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",18,52)' in s
 assert 'detailTitle:SetShown(#filtered==0)' in s
 assert 'row.name:SetWidth(270)' in s and 'cols[1][2]+273' in s
for relative in ('Market/FlipPanel.lua','Crafting/FlipPanel.lua','Trading.lua','Market/Demand.lua','PurchaseHistory.lua'):
 s=(root/relative).read_text(encoding='utf8');lua.execute('assert(loadstring(...))',s)
 assert 'AuctionPanelExtraWidth or 367' in s,relative
print('Resizable rows, matching widths, footer placement and Lua syntax passed.')
