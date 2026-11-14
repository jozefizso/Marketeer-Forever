#!/usr/bin/env python3
"""Seed and incrementally fill the market item-name catalog."""
import argparse
import json
import re
import sqlite3
import time
import urllib.request
from urllib.parse import quote


def valid_name(value):
    return isinstance(value,str) and 0<len(value)<=160 and not any(ord(c)<32 for c in value) and not re.fullmatch(r'(?:item|unknown)\s*#?\s*\d+',value,re.I)


def seed(db,legacy):
    with sqlite3.connect('file:'+quote(legacy,safe='/')+'?mode=ro',uri=True) as old:
        rows=[(int(item),name) for item,name in old.execute('select item_id,name from names') if valid_name(name)]
    with db:db.executemany('insert or ignore into item_names(item,name) values (?,?)',rows)
    return len(rows)


def fill(db, limit):
    missing=list(db.execute('select p.item,min(p.market) from low_prices p left join item_names n on p.item=n.item where n.item is null group by p.item order by p.item limit ?', (limit,)))
    groups={}
    for item,market in missing:groups.setdefault(market,[]).append(item)
    done=0; errors=[]
    for market,ids in groups.items():
        for i in range(0,len(ids),100):
            batch=ids[i:i+100];url='https://api.ahledger.com/v1/tooltip/'+market.replace('/','.')+'?items='+','.join(map(str,batch))
            try:
                req=urllib.request.Request(url,headers={'User-Agent':'MarketeerForever/1.0 (+https://devvy.xyz/marketeer/)'})
                with urllib.request.urlopen(req,timeout=30) as response:
                    if 'no-store' in response.headers.get('Cache-Control','').lower():raise ValueError('upstream prohibits storage')
                    payload=json.load(response)
                allowed=set(batch);rows=[]
                for item in payload.get('items',[]):
                    if isinstance(item,dict) and item.get('id') in allowed and valid_name(item.get('name')):rows.append((item['id'],item['name']))
                with db:db.executemany('insert or ignore into item_names(item,name) values (?,?)',rows)
                done+=len(rows)
            except (OSError,ValueError,TypeError) as exc:errors.append(str(exc))
            time.sleep(.5)
    return len(missing),done,errors


def main():
    p=argparse.ArgumentParser();p.add_argument('--db',required=True);p.add_argument('--legacy-db',required=True);p.add_argument('--limit',type=int,default=2000);args=p.parse_args()
    with sqlite3.connect(args.db,timeout=30) as db:
        db.execute('create table if not exists item_names(item integer primary key,name text not null)')
        seeded=seed(db,args.legacy_db);missing,added,errors=fill(db,max(0,args.limit))
    print(json.dumps({'seeded':seeded,'missing_checked':missing,'added':added,'errors':errors}))
    return 1 if errors else 0
if __name__=='__main__':raise SystemExit(main())
