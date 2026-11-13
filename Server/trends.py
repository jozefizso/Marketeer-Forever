#!/usr/bin/env python3
"""Build rolling AHledger market-price summaries without changing the live API."""
import argparse
import json
import re
import sqlite3
import statistics
import time
from pathlib import Path

HOUR = 3600
RETENTION = 14 * 24 * HOUR
MARKET = re.compile(r'^forever/(normal|pvp|rp|rppvp)/(alliance|horde)/(us|eu|cn)$')
ROW = re.compile(r'^\d+(?::\d*){8}$')


def connect(path):
    db = sqlite3.connect(path, timeout=30)
    db.execute('CREATE TABLE IF NOT EXISTS prices (market TEXT NOT NULL, item INTEGER NOT NULL, hour INTEGER NOT NULL, observed INTEGER NOT NULL, price INTEGER NOT NULL, PRIMARY KEY(market,item,hour)) WITHOUT ROWID')
    db.execute('CREATE INDEX IF NOT EXISTS prices_observed_expiry ON prices(observed)')
    db.execute('CREATE TABLE IF NOT EXISTS low_prices (market TEXT NOT NULL, item INTEGER NOT NULL, hour INTEGER NOT NULL, observed INTEGER NOT NULL, price INTEGER NOT NULL, PRIMARY KEY(market,item,hour)) WITHOUT ROWID')
    db.execute('CREATE INDEX IF NOT EXISTS low_prices_expiry ON low_prices(observed)')
    return db


def parse_snapshot(snapshot, now):
    market, body = snapshot.get('market'), snapshot.get('body')
    if not isinstance(market, str) or not MARKET.fullmatch(market) or not isinstance(body, str) or len(body) > 2_000_000:
        raise ValueError('Invalid snapshot')
    lines = body.replace('\r', '').strip().split('\n')
    header = lines[0].split('|')
    if len(header) != 4 or header[:2] != ['AHL1', market] or not header[2].isdigit() or not header[3].isdigit():
        raise ValueError('Invalid header')
    observed, count = int(header[2]), int(header[3])
    if observed <= 0 or observed > now + 300 or not 0 <= count <= 100000 or len(lines) - 1 != count:
        raise ValueError('Invalid timestamp or row count')
    rows, seen = [], set()
    for line in lines[1:]:
        if not ROW.fullmatch(line):
            raise ValueError('Invalid row')
        cols = line.split(':')
        item = int(cols[0])
        if item <= 0 or item in seen:
            raise ValueError('Invalid or duplicate item')
        seen.add(item)
        median = int(cols[1]) if cols[1] and int(cols[1]) > 0 else None
        low = int(cols[2]) if cols[2] and int(cols[2]) > 0 else None
        if median is not None or low is not None:
            rows.append((market, item, observed // HOUR * HOUR, observed, median, low))
    return rows


def ingest(db, snapshot, now):
    rows = parse_snapshot(snapshot, now)
    rows = [row for row in rows if row[3] >= now - RETENTION]
    with db:
        for table,index in (('prices',4),('low_prices',5)):
            entries = [(r[0],r[1],r[2],r[3],r[index]) for r in rows if r[index] is not None]
            db.executemany(f'INSERT INTO {table} VALUES (?,?,?,?,?) ON CONFLICT(market,item,hour) DO UPDATE SET observed=excluded.observed, price=excluded.price WHERE excluded.observed>{table}.observed', entries)
    return len(rows)


def prune(db, now):
    # Remove observations outside the rolling retention window.
    with db:
        total = db.execute('DELETE FROM prices WHERE observed < ?', (now - RETENTION,)).rowcount
        return total + db.execute('DELETE FROM low_prices WHERE observed < ?', (now - RETENTION,)).rowcount


def window(rows, start, end, min_samples, min_span):
    values = [(t, p) for t, p in rows if start <= t < end]
    if not values:
        return {'median': None, 'samples': 0, 'span_hours': 0, 'sufficient': False}
    span = (values[-1][0] - values[0][0]) / HOUR
    return {'median': statistics.median(p for _, p in values), 'samples': len(values), 'span_hours': round(span, 1), 'sufficient': len(values) >= min_samples and span >= min_span}


def summarize(db, market, item, now):
    if not MARKET.fullmatch(market) or item <= 0:
        raise ValueError('Invalid market or item')
    rows = list(db.execute('SELECT observed,price FROM prices WHERE market=? AND item=? AND observed>=? AND observed<=? ORDER BY observed', (market, item, now - RETENTION, now)))
    recent = window(rows, now - 24 * HOUR, now + 1, 4, 12)
    previous = window(rows, now - 48 * HOUR, now - 24 * HOUR, 4, 12)
    hours48 = window(rows, now - 48 * HOUR, now + 1, 8, 24)
    days14 = window(rows, now - RETENTION, now + 1, 48, 7 * 24)
    def change(a, b):
        return round((a['median'] / b['median'] - 1) * 100, 1) if a['sufficient'] and b['sufficient'] and b['median'] else None
    return {'market': market, 'item': item, 'as_of': now, 'last_observed': rows[-1][0] if rows else None, 'price_basis': 'median of hourly AHledger market medians in copper', 'attribution': {'text': 'Prices from AHledger', 'url': 'https://ahledger.com'}, 'last_24h': recent, 'previous_24h': previous, 'last_48h': hours48, 'last_14d': days14, 'change_24h_vs_previous_24h_pct': change(recent, previous), 'change_24h_vs_14d_pct': change(recent, days14)}


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--db', required=True)
    sub = p.add_subparsers(dest='command', required=True)
    i = sub.add_parser('ingest'); i.add_argument('snapshot', nargs='+')
    s = sub.add_parser('summary'); s.add_argument('market'); s.add_argument('item', type=int)
    sub.add_parser('prune')
    args = p.parse_args(); now = int(time.time())
    with connect(args.db) as db:
        if args.command == 'ingest':
            print(json.dumps({'rows_processed': sum(ingest(db, json.loads(Path(f).read_text(encoding='utf-8')), now) for f in args.snapshot)}))
        elif args.command == 'prune':
            print(json.dumps({'rows_deleted': prune(db, now)}))
        else:
            print(json.dumps(summarize(db, args.market, args.item, now), indent=2))


if __name__ == '__main__':
    main()
