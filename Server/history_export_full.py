#!/usr/bin/env python3
"""Export every available hourly low for one market, using base-36 values."""
import itertools
import sqlite3
import sys
import time
from urllib.parse import quote
import trends


def b36(value):
    chars='0123456789abcdefghijklmnopqrstuvwxyz'
    if value==0: return '0'
    result=''
    while value: value,r=divmod(value,36);result=chars[r]+result
    return result


def export(db,market,now):
    if not trends.MARKET.fullmatch(market): raise ValueError('Invalid market')
    current_hour=now//trends.HOUR
    rows=db.execute('SELECT item,hour,price FROM low_prices WHERE market=? AND observed>=? AND observed<=? ORDER BY item,hour',(market,now-trends.RETENTION,now))
    output=[]
    for item,group in itertools.groupby(rows,key=lambda r:r[0]):
        points=['%s,%s'%(b36(current_hour-hour//trends.HOUR),b36(price*2)) for _,hour,price in group]
        if points:output.append('%d:%s'%(item,';'.join(points)))
    return 'HST2|%s|%d|%d\n%s\n'%(market,now,len(output),'\n'.join(output))


if __name__=='__main__':
    if len(sys.argv)!=3:raise SystemExit('Expected database and market')
    db=sqlite3.connect('file:'+quote(sys.argv[1],safe='/')+'?mode=ro',uri=True,timeout=30)
    try:print(export(db,sys.argv[2],int(time.time())),end='')
    finally:db.close()
