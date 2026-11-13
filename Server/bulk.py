#!/usr/bin/env python3
"""Export a compact, market-specific snapshot of eligible trend summaries."""
import itertools
import sqlite3
import sys
import time
from urllib.parse import quote
import trends


def export(db, market, now):
    if not trends.MARKET.fullmatch(market):
        raise ValueError('Invalid market')
    rows = db.execute('SELECT item,observed,price FROM prices WHERE market=? AND observed>=? AND observed<=? ORDER BY item,observed', (market, now-trends.RETENTION, now))
    output = []
    for item, group in itertools.groupby(rows, key=lambda row: row[0]):
        values = [(t, p) for _, t, p in group]
        if not values or now-values[-1][0] > 48*trends.HOUR:
            continue
        recent = trends.window(values, now-24*trends.HOUR, now+1, 4, 12)
        previous = trends.window(values, now-48*trends.HOUR, now-24*trends.HOUR, 4, 12)
        hours48 = trends.window(values, now-48*trends.HOUR, now+1, 8, 24)
        days14 = trends.window(values, now-trends.RETENTION, now+1, 48, 7*24)
        def amount(window):
            return str(int(window['median']*2)) if window['sufficient'] else ''
        change = ''
        if recent['sufficient'] and previous['sufficient'] and previous['median']:
            change = str(round((recent['median']/previous['median']-1)*1000))
        output.append(f"{item}:{amount(recent)}:{amount(hours48)}:{amount(days14)}:{change}:{values[-1][0]}")
    return f"TRD1|{market}|{now}|{len(output)}\n" + '\n'.join(output) + '\n'


if __name__ == '__main__':
    if len(sys.argv) != 3: raise SystemExit('Expected database and market')
    db = sqlite3.connect('file:' + quote(sys.argv[1], safe='/') + '?mode=ro', uri=True, timeout=30)
    try: print(export(db, sys.argv[2], int(time.time())), end='')
    finally: db.close()
