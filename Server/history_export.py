#!/usr/bin/env python3
"""Compact history: hourly lows for 48h, daily median lows after that."""
import itertools
import sqlite3
import statistics
import sys
import time
from urllib.parse import quote
import trends


def export(db, market, now):
    if not trends.MARKET.fullmatch(market): raise ValueError('Invalid market')
    current_hour = now // trends.HOUR
    cutoff = now - trends.RETENTION
    rows = db.execute('SELECT item,hour,price FROM low_prices WHERE market=? AND observed>=? AND observed<=? ORDER BY item,hour', (market,cutoff,now))
    output=[]
    for item, group in itertools.groupby(rows, key=lambda r:r[0]):
        hourly=[]; days={}
        for _,hour,price in group:
            if hour >= now-48*trends.HOUR:
                hourly.append((hour,price*2))
            else:
                day=hour//86400; days.setdefault(day,[]).append((hour,price))
        points=[(values[-1][0],int(statistics.median(p for _,p in values)*2)) for _,values in sorted(days.items())]+hourly
        points.sort()
        if points:
            encoded=';'.join(f'{current_hour-hour//trends.HOUR},{price}' for hour,price in points)
            output.append(f'{item}:{encoded}')
    return f'HST1|{market}|{now}|{len(output)}\n'+'\n'.join(output)+'\n'


if __name__=='__main__':
    if len(sys.argv)!=3: raise SystemExit('Expected database and market')
    db=sqlite3.connect('file:'+quote(sys.argv[1],safe='/')+'?mode=ro',uri=True,timeout=30)
    try: print(export(db,sys.argv[2],int(time.time())),end='')
    finally: db.close()
