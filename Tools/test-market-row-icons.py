from pathlib import Path
import re,sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'.test-deps'))
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]/'MarketeerForever'
market=(root/'Market/FlipPanel.lua').read_text(encoding='utf8')
craft=(root/'Crafting/FlipPanel.lua').read_text(encoding='utf8')
start=market.index('local requestedRowIcons={}')
end=market.index('local function marketGap(item)',start)
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
MarketeerForeverCore={};requests=0;C_Item={GetItemIconByID=function(id)if id==1 then return 1234 end end,RequestLoadItemDataByID=function()requests=requests+1 end}
GetItemIcon=function(id)if id==2 then return 5678 end end
'''+market[start:end]+'''
assert(MarketeerForeverCore.MarketRowIcon(1)==1234)
assert(MarketeerForeverCore.MarketRowIcon(2)==5678)
assert(MarketeerForeverCore.MarketRowIcon(3)==134400 and requests==1)
assert(MarketeerForeverCore.MarketRowIcon(3)==134400 and requests==1)
''')
for text in (market,craft):
 lua.execute('assert(loadstring(...))',text)
 cols=re.search(r'local cols=\{(\{"ITEM / VENDOR".*?\})\}',text).group(1)
 values=[(int(x),int(w)) for x,w in re.findall(r'\{"[^\"]+",(\d+),(\d+)\}',cols)]
 assert len(values)==8 and all(values[i][0]+values[i][1] <= values[i+1][0] for i in range(7)),values
 assert 'row.icon:SetSize(26,26)' in text and 'cols[1][2]+273' in text
 assert 'cols[8][2],-11,cols[8][3]' in text
print('Icon lookup, missing-item fallback and aligned row/header columns passed.')
