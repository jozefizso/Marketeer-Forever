#!/usr/bin/env python3
"""Export robust historical lows for one market; prices are twice copper."""
import itertools
import sqlite3
import sys
import time
from urllib.parse import quote
import trends


def export(db, market, now):
    if not trends.MARKET.fullmatch(market): raise ValueError('Invalid market')
    rows=db.execute('SELECT item,observed,price FROM low_prices WHERE market=? AND observed>=? AND observed<=? ORDER BY item,observed', (market,now-trends.RETENTION,now))
    result=[]
    for item, group in itertools.groupby(rows, key=lambda row:row[0]):
        values=[(t,p) for _,t,p in group]
        if not values or now-values[-1][0]>48*trends.HOUR: continue
        recent=trends.window(values,now-6*trends.HOUR,now+1,3,2)
        day=trends.window(values,now-24*trends.HOUR,now+1,4,12)
        two=trends.window(values,now-48*trends.HOUR,now+1,8,24)
        fortnight=trends.window(values,now-trends.RETENTION,now+1,48,7*24)
        def value(w): return str(int(w['median']*2)) if w['sufficient'] else ''
        result.append(f"{item}:{value(day)}:{value(two)}:{value(fortnight)}:{value(recent)}:{values[-1][0]}")
    return f'TRD2|{market}|{now}|{len(result)}\n'+'\n'.join(result)+'\n'


if __name__=='__main__':
    if len(sys.argv)!=3: raise SystemExit('Expected database and market')
    db=sqlite3.connect('file:'+quote(sys.argv[1],safe='/')+'?mode=ro',uri=True,timeout=30)
    try: print(export(db,sys.argv[2],int(time.time())),end='')
    finally: db.close()
