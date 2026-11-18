from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'.test-deps'))
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]/'MarketeerForever'
lua=LuaRuntime(unpack_returned_tuples=True)
for p in ('Crafting/FlipPanel.lua','Crafting/RecipeBrowser.lua','Menu.lua'):
 lua.execute('assert(loadstring(...))',(root/p).read_text(encoding='utf8'))
s=(root/'Crafting/FlipPanel.lua').read_text(encoding='utf8')
a=s.index('    row:SetScript("OnClick",function(self,button)',s.index('row:RegisterForClicks("LeftButtonUp","RightButtonUp")'));b=s.index(');rows[i]=row',a)
callback=s[a:b+1].strip()
lua.execute('''row={SetScript=function(self,event,fn) click=fn end};viewMode='craft';alt=true;IsAltKeyDown=function()return alt end;MarketeerForeverCore={ShowItemDrops=function(id) result={'sources',id} end,ShowMarketHistory=function(id)result={'history',id}end};setSelected=function(item)result={'select',item.id}end\n'''+callback+'''\nlocal r={item={id=7,recipe={id=12}}};click(r,'RightButton');assert(result[1]=='sources' and result[2]==7);r.item={id=8};click(r,'RightButton');assert(result[1]=='sources' and result[2]==8);click(r,'LeftButton');assert(result[1]=='history');alt=false;click(r,'LeftButton');assert(result[1]=='select' and result[2]==8);result=nil;click(r,'RightButton');assert(result==nil);alt=true;viewMode='flips';click(r,'RightButton');assert(result==nil)''')
s=(root/'Crafting/RecipeBrowser.lua').read_text(encoding='utf8');a=s.index('local function find(id,recipeID)');b=s.index('\nfunction core.CreateRecipeBrowser',a)
lua.execute('''local PAGE=4;local matches,selected,offset={},nil,0;local search={GetText=function()return 'item' end};local entries={};for i=1,6 do entries[i]={output=7,name=string.char(64+i)} end;local function data()return entries end;local function nameFor()return '' end;local function render()end;local pageText={SetText=function()end}\n'''+s[a:b]+'''\nfind(7,6);assert(selected==6 and offset==4);find(7);assert(selected==1 and offset==0)''')
print('Lua syntax, row shortcuts, and exact recipe selection passed.')

s=(root/'Market/FlipPanel.lua').read_text(encoding='utf8')
lua.execute('assert(loadstring(...))',s)
a=s.index('    row:SetScript("OnClick",function(self,button)',s.index('row:RegisterForClicks("LeftButtonUp","RightButtonUp")'));b=s.index(');rows[i]=row',a)
callback=s[a:b+1].strip()
lua.execute('''row={SetScript=function(self,event,fn) click=fn end};alt=true;IsAltKeyDown=function()return alt end;MarketeerForeverCore={ShowItemDrops=function(id) result={'sources',id} end,ShowMarketHistory=function(id)result={'history',id}end};setSelected=function(item)result={'select',item.id}end\n'''+callback+'''\nlocal r={item={id=17}};click(r,'RightButton');assert(result[1]=='sources' and result[2]==17);click(r,'LeftButton');assert(result[1]=='history' and result[2]==17);alt=false;click(r,'LeftButton');assert(result[1]=='select');result=nil;click(r,'RightButton');assert(result==nil)''')
print('Vendor flip source and history shortcuts passed.')

s=(root/'Crafting/RecipeBrowser.lua').read_text(encoding='utf8')
a=s.index('local function auctionAvailable()');b=s.index('local function renderDetail()',a)
lua.execute("""local selected=1;local function data()return {[1]={output=7}} end;local shown={};local auctionButton={SetShown=function(_,v)shown.output=v end};local materialRows={{id=5,auctions={SetShown=function(_,v)shown.material=v end}}};local core={active=true,OpenItemAuctions=function()end};local open=true;AuctionHouseFrame={IsShown=function()return open end}\n"""+s[a:b]+"""\nupdateAuctionButton();assert(shown.output and shown.material);open=false;updateAuctionButton();assert(not shown.output and not shown.material);open=true;materialRows[1].id=nil;updateAuctionButton();assert(shown.output and not shown.material)""")
assert "core.OpenItemAuctions(row.id)" in s and "row.auctions:SetPoint('RIGHT',row.sources,'LEFT',-4,0)" in s
print('Material auction button visibility and item targeting passed.')
