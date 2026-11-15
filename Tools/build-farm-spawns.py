"""Derive labeled Classic reference spawn points from the local CMaNGOS dump."""
import csv, gzip, math, re
from pathlib import Path

root=Path(__file__).resolve().parents[2]
farm=root/'Marketeer-Forever/MarketeerForever/Market/FarmData.lua'
sql=root/'NokiMarket/data/classic-reference/ClassicDB_1_12_1_z2815.sql.gz'
targets={}
for line in farm.read_text(encoding='utf8').splitlines():
 m=re.match(r'^\[(\d+)\]=\{name="((?:[^"\\]|\\.)*)",min=',line)
 if m:
  import json
  targets[int(m.group(1))]=json.loads('"'+m.group(2)+'"')
templates={};spawns={}
pattern=re.compile(r"\((?:[^()'\\]|\\.|'(?:\\.|[^'\\])*')*\)")
with gzip.open(sql,'rt',encoding='utf8',errors='replace') as f:
 for line in f:
  if line.startswith('INSERT INTO `creature_template`'):
   for m in pattern.finditer(line.split(' VALUES ',1)[1]):
    row=next(csv.reader([m.group()[1:-1]],delimiter=',',quotechar="'",escapechar='\\'))
    try:
     ident=int(row[0])
     if ident in targets:templates[ident]=row[1]
    except (ValueError,IndexError):pass
  elif line.startswith('INSERT INTO `creature` VALUES '):
   for m in pattern.finditer(line.split(' VALUES ',1)[1]):
    row=m.group()[1:-1].split(',')
    try:
     ident,world=int(row[1]),int(row[2]);x,y=float(row[4]),float(row[5])
     if ident in targets and world in (0,1) and math.isfinite(x) and math.isfinite(y):spawns.setdefault(ident,[]).append((world,round(x,1),round(y,1)))
    except (ValueError,IndexError):pass
output=['-- Classic 1.12 reference spawn positions; not verified for Forever.','-- CMaNGOS Classic DB, GPL-3.0: https://github.com/cmangos/classic-db','MarketeerForeverFarmSpawns={']
for ident,points in sorted(spawns.items()):
 if templates.get(ident,'').casefold()!=targets[ident].casefold():continue
 points=sorted(set(points))
 if len(points)>100:points=[points[round(i*(len(points)-1)/99)] for i in range(100)]
 output.append('[%d]={%s},'%(ident,','.join('{%d,%.1f,%.1f}'%p for p in points)))
output.append('}')
dest=root/'Marketeer-Forever/MarketeerForever/Market/FarmSpawns.lua'
dest.write_text('\n'.join(output)+'\n',encoding='utf8')
print('Matched creature IDs:',len(output)-3,'bytes:',dest.stat().st_size,'Highland Strider:',2559 in spawns and templates.get(2559,'').casefold()==targets.get(2559,'').casefold())
