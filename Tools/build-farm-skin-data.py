"""Index the existing item-source snapshot by unique creature name."""
from collections import defaultdict
from pathlib import Path
import re
import sys

root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'.test-deps'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
for name in ('FarmData.lua','FarmLookupData.lua'):
    lua.execute((root/'MarketeerForever/Market'/name).read_text(encoding='utf8'))
mobdata=lua.globals().MarketeerForeverFarmData.mobs
lookup=lua.globals().MarketeerForeverFarmLookup['items']
names=defaultdict(list)
for ident,mob in mobdata.items(): names[mob.name.casefold()].append(ident)
data=defaultdict(dict);ambiguous=0
for item_id,item in lookup.items():
    for _,source in (item.sources or lua.table()).items():
        if source[6]!='Skinned from': continue
        name,rate,samples=source[1],source[4],source[5]
        if not isinstance(name,str) or not isinstance(rate,(int,float)) or not 0<rate<=100: continue
        matching=names.get(name.casefold(),[])
        if len(matching)!=1:
            if len(matching)>1: ambiguous+=1
            continue
        match=re.search(r'([\d,]+) out of ([\d,]+)',samples or '')
        total=int(match.group(2).replace(',','')) if match else 0
        fallback=isinstance(samples,str) and 'Classic Era' in samples
        candidate=(item_id,rate,total,fallback)
        previous=data[matching[0]].get(item_id)
        if previous is None or (not fallback,total)>(not previous[3],previous[2]): data[matching[0]][item_id]=candidate
out=root/'MarketeerForever/Market/FarmSkinData.lua'
with out.open('w',encoding='utf8',newline='\n') as f:
    f.write('-- Derived from the existing item-source snapshot; ambiguous creature names are excluded.\nMarketeerForeverFarmSkinData={\n')
    for npc,entries in sorted(data.items()):
        f.write('[%d]={%s},\n'%(npc,','.join('{%d,%s,%d,%s}'%(item,rate,total,'true' if fallback else 'false') for item,rate,total,fallback in sorted(entries.values()))))
    f.write('}\n')
print('Skinning records:',sum(map(len,data.values())),'creatures:',len(data),'ambiguous sources omitted:',ambiguous)
