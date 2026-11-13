#!/usr/bin/env python3
"""Collect each AHledger market into an independent rolling history database."""
import argparse
import datetime
import itertools
import json
import time
import urllib.error
import urllib.request
from pathlib import Path
import trends


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--db', required=True)
    parser.add_argument('--backfill-dir')
    parser.add_argument('--delay', type=float, default=2)
    parser.add_argument('--archive-licensed', action='store_true', help='Use only when AHledger has granted permission to archive its data')
    args = parser.parse_args()
    now = int(time.time())
    cutoff = int(datetime.datetime(2026, 12, 10, tzinfo=datetime.timezone.utc).timestamp())
    if now >= cutoff and not args.archive_licensed:
        raise SystemExit('AHledger archive permission is required from 2026-12-10; collection stopped.')
    failures = []
    with trends.connect(args.db) as db:
        if args.backfill_dir:
            for path in sorted(Path(args.backfill_dir).glob('*.json')):
                try:
                    trends.ingest(db, json.loads(path.read_text(encoding='utf-8')), now)
                except (ValueError, OSError, KeyError) as exc:
                    failures.append(f'{path.name}: {exc}')
        markets = itertools.product(('us', 'eu', 'cn'), ('normal', 'pvp', 'rp', 'rppvp'), ('alliance', 'horde'))
        for region, ruleset, faction in markets:
            market = f'forever/{ruleset}/{faction}/{region}'
            url = f'https://api.ahledger.com/v1/pricetable/forever.{ruleset}.{faction}.{region}'
            try:
                request = urllib.request.Request(url, headers={'User-Agent': 'MarketeerForever/1.0 (+https://devvy.xyz/marketeer/)'})
                with urllib.request.urlopen(request, timeout=30) as response:
                    cache_control = response.headers.get('Cache-Control', '').lower()
                    if 'no-store' in cache_control:
                        raise ValueError('upstream prohibits storage')
                    raw = response.read(2_000_001)
                    if len(raw) > 2_000_000:
                        raise ValueError('oversized response')
                count = trends.ingest(db, {'market': market, 'body': raw.decode('utf-8')}, now)
                print(f'{market}: {count} rows', flush=True)
            except (OSError, ValueError, UnicodeError, urllib.error.URLError) as exc:
                failures.append(f'{market}: {exc}')
            time.sleep(max(0, args.delay))
        deleted = trends.prune(db, now)
    for failure in failures:
        print('FAILED:', failure, flush=True)
    print(f'Expired hourly prices: {deleted}; failures: {len(failures)}', flush=True)
    return 1 if failures else 0


if __name__ == '__main__':
    raise SystemExit(main())
