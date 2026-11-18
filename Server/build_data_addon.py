#!/usr/bin/env python3
"""Build a market-isolated, load-on-demand Marketeer data addon ZIP."""
import argparse
import itertools
import json
import sqlite3
import time
import urllib.request
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

import bulk_low
import history_export_full
import trends

MARKETS = [f'forever/{rules}/{faction}/{region}' for region,rules,faction in itertools.product(
    ('us','eu','cn','kr'), ('normal','pvp','rp','rppvp'), ('alliance','horde'))]

def lua_string(value):
    return '"'+''.join('\\%03d'%b for b in value.encode('utf-8'))+'"'

def parse_market(body, market, now):
    # The same validation used by the collector; retain the source timestamp.
    trends.parse_snapshot({'market':market,'body':body},now)
    header,rows=body.replace('\r','').split('\n',1)
    parts=header.split('|')
    return int(parts[2]),int(parts[3]),rows.strip()

def fetch_market(market):
    req=urllib.request.Request('https://api.ahledger.com/v1/pricetable/'+market.replace('/','.'), headers={'User-Agent':'MarketeerForeverData/1.0 (+https://devvy.xyz/marketeer/)'})
    with urllib.request.urlopen(req, timeout=40) as response:
        if 'no-store' in response.headers.get('Cache-Control','').lower(): raise ValueError('Source forbids storage: '+market)
        raw=response.read(2_000_001)
        if len(raw)>2_000_000: raise ValueError('Market too large: '+market)
        return raw.decode('utf-8')

def name_file(db):
    lines=['_G.MarketeerSnapshotCompanion=1','_G.MarketeerSnapshotItemNames={schemaVersion=1,items={']
    for item,name in db.execute('select item,name from item_names order by item'):
        if isinstance(item,int) and item>0 and isinstance(name,str) and name:
            lines.append('[%d]=%s,'%(item,lua_string(name)))
    return '\n'.join(lines)+'\n}}\n'

def module_data(db,market,now,body):
    observed,count,rows=parse_market(body,market,now)
    history=history_export_full.export(db,market,now).splitlines()
    summary=bulk_low.export(db,market,now).splitlines()
    lines=['-- Prices from AHledger (ahledger.com).',
           '_G.MarketeerSnapshotMarketData={schemaVersion=1,periodHours=24,tables={[%s]={updated=%d,count=%d,text=[==[\n%s\n]==]}}}'%(lua_string(market),observed,count,rows),
           '_G.MarketeerSnapshotHistory={schemaVersion=2,market=%s,generatedAt=%d,items={'%(lua_string(market),now)]
    for row in filter(None,history[1:]):
        item,points=row.split(':',1);lines.append('[%d]="%s",'%(int(item),points))
    lines.extend(['}}','_G.MarketeerSnapshotTrends={schemaVersion=2,market=%s,generatedAt=%d,items={'%(lua_string(market),now)])
    for row in filter(None,summary[1:]):
        fields=row.split(':');lines.append('[%d]={%s},'%(int(fields[0]),','.join(x or 'false' for x in fields[1:])))
    lines.append('}}')
    return '\n'.join(lines)+'\n'

def build(db,output,markets,now,fetch=fetch_market):
    if not markets or len(markets)!=len(set(markets)) or any(not trends.MARKET.fullmatch(m) for m in markets): raise ValueError('Invalid market list')
    with ZipFile(output,'w',ZIP_DEFLATED,compresslevel=6) as z:
        z.writestr('MarketeerMarketSnapshots/MarketeerMarketSnapshots.toc','## Interface: 16001\n## Title: Marketeer Market Data\n## IconTexture: Interface\\MoneyFrame\\UI-GoldIcon\n## Notes: Price history and estimates from AHledger (ahledger.com)\n## Version: %d\nNames.lua\n'%now)
        z.writestr('MarketeerMarketSnapshots/Names.lua',name_file(db))
        for market in markets:
            module='MarketeerSnapshot_'+market.replace('/','_')
            z.writestr(module+'/'+module+'.toc','## Interface: 16001\n## Title: Marketeer Market Data: %s\n## Group: MarketeerMarketSnapshots\n## IconTexture: Interface\\MoneyFrame\\UI-GoldIcon\n## Dependencies: MarketeerMarketSnapshots\n## LoadOnDemand: 1\nData.lua\n'%market)
            z.writestr(module+'/Data.lua',module_data(db,market,now,fetch(market)))
            print('Built',market,flush=True)

def main():
    p=argparse.ArgumentParser();p.add_argument('--db',required=True);p.add_argument('--output',required=True);p.add_argument('--market',action='append');args=p.parse_args()
    output=Path(args.output);tmp=output.with_suffix(output.suffix+'.tmp')
    db=sqlite3.connect('file:'+args.db+'?mode=ro',uri=True,timeout=30)
    try:
        build(db,tmp,args.market or MARKETS,int(time.time()))
        with ZipFile(tmp) as archive:
            if archive.testzip(): raise ValueError('Corrupt package')
        tmp.replace(output)
    finally:
        db.close()
        if tmp.exists(): tmp.unlink()

if __name__=='__main__': main()
