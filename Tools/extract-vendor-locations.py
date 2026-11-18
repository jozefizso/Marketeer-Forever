"""Extract QuestieDB Forever's baked vendor and NPC fields for local testing."""
import base64
import json
import re
import struct
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
toc = Path(sys.argv[1])
data = {}
for line in toc.open(encoding='utf-8'):
    m = re.match(r'^## (X-(?:Item-\d+-14|Npc-\d+-(?:S|7))(?:-\d+)?):\s*(.*)$', line)
    if m: data[m[1]] = m[2].strip()

def decode(key):
    value = data.get(key)
    if not value: return None
    if re.fullmatch(r'~\d+~', value):
        value = ''.join(data[key+'-'+str(i)] for i in range(1, int(value[1:-1])+1))
    raw = base64.b64decode(value)
    offset = 0
    def read():
        nonlocal offset
        b = raw[offset]; offset += 1
        kind, arg = b >> 5, b & 31
        if arg < 24: n = arg
        elif arg in (24, 25, 26, 27):
            size = {24:1,25:2,26:4,27:8}[arg]
            part = raw[offset:offset+size]; offset += size
            if kind == 7 and arg in (25,26,27): return struct.unpack({25:'>e',26:'>f',27:'>d'}[arg], part)[0]
            n = int.from_bytes(part,'big')
        else: raise ValueError('Unsupported CBOR encoding')
        if kind == 0: return n
        if kind == 1: return -1-n
        if kind in (2,3):
            part=raw[offset:offset+n];offset+=n
            return part.decode('utf-8')
        if kind == 4: return [read() for _ in range(n)]
        if kind == 5: return {read():read() for _ in range(n)}
        if kind == 7: return {20:False,21:True,22:None}.get(n)
        raise ValueError('Unsupported CBOR type')
    result=read()
    if offset != len(raw): raise ValueError('Trailing CBOR data')
    return result

items={}
for key in data:
    m=re.fullmatch(r'X-Item-(\d+)-14',key)
    if m:
        ids=decode(key)
        if isinstance(ids,list) and ids: items[int(m[1])]=ids
ids={i for vendors in items.values() for i in vendors}
npcs={}
for npc in ids:
    row=decode('X-Npc-%d-S'%npc);spawns=decode('X-Npc-%d-7'%npc)
    if isinstance(row,dict) and isinstance(spawns,dict) and row.get(1) and row.get(13) in ('A','H','AH'):
        npcs[npc]=(row[1],row[13],spawns)

def lua(value):
    if value is None: return 'nil'
    if isinstance(value,str): return json.dumps(value,ensure_ascii=False)
    if isinstance(value,(int,float)): return repr(value)
    if isinstance(value,list): return '{'+','.join(lua(x) for x in value)+'}'
    if isinstance(value,dict): return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in value.items())+'}'
    raise TypeError(type(value))

map_source=(toc.parent/'support/Forever/Zones/areaIdToUiMapId.lua').read_text(encoding='utf-8')
map_block=map_source.split('ZoneDB.private.areaIdToUiMapId = [[return {',1)[1].split('}]]',1)[0]
areas={int(k):int(v) for k,v in re.findall(r'\[(\d+)\]\s*=\s*(\d+)',map_block)}
out=root/'MarketeerForever/Market/LocalVendorLocations.lua'
with out.open('w',encoding='utf-8',newline='\n') as f:
    f.write('-- QuestieDB Forever 1.1.3 vendor data; see data/questiedb/LICENSE.md.\nMarketeerLocalVendors={items=')
    f.write(lua(items));f.write(',npcs=');f.write(lua({k:list(v) for k,v in npcs.items()}));f.write(',areas=');f.write(lua(areas));f.write('}\n')
print('items',len(items),'vendor NPCs with locations',len(npcs),'area maps',len(areas),'bytes',out.stat().st_size)
